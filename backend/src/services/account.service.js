const User = require('../models/User');
const Like = require('../models/Like');
const Match = require('../models/Match');
const Message = require('../models/Message');
const Block = require('../models/Block');
const Report = require('../models/Report');
const PendingImageDelete = require('../models/PendingImageDelete');
// Phase 1.17 — capture cascade summary into DeletionRequest before deleting.
const DeletionRequest = require('../models/DeletionRequest');
const { deleteImage } = require('./upload.service');
const AppError = require('../utils/AppError');
const logger = require('../utils/logger');
const { cacheDelPattern } = require('../utils/cache');
const withTransaction = require('../utils/withTransaction');

const sessionOpt = (session) => (session ? { session } : {});

/**
 * Permanently delete a user account and all associated data.
 *
 * The multi-document cascade (User + Likes + Matches + Messages + Blocks +
 * Reports) runs inside a Mongo transaction when supported by the cluster so a
 * partial failure rolls everything back. Cloudinary deletes and Redis cache
 * cleanup run AFTER the transaction commits — they are best-effort and any
 * orphans are reaped by the image-cleanup job (see deletePhoto for the same
 * mongo-first, cloudinary-second pattern).
 *
 * Sockets owned by the user are forcibly disconnected once all DB cascades
 * have committed. We synchronously call `socket.disconnect(true)` (the socket
 * cleanly tears down on the next tick — no need to await).
 *
 * Phase 1.17 — GDPR audit:
 *   - Capture a cascade summary (counts of every doc deleted) BEFORE the
 *     cascade runs (we count, then delete).
 *   - Persist a `DeletionRequest` row AFTER the cascade succeeds. This row
 *     survives the user indefinitely as the audit trail.
 *
 * Phase 1.2 — image reaper integration:
 *   - On Cloudinary delete failure during the cascade, push the publicId to
 *     `PendingImageDelete` rather than just logging. The reaper job sweeps
 *     these up later.
 */
const deleteAccount = async (userId, io, ctx = {}) => {
  const user = await User.findById(userId);
  if (!user) throw new AppError('User not found', 404);

  // Snapshot for the audit row.
  const userEmail = user.email || null;

  // Capture publicIds before the DB doc is deleted so we can reap them after.
  const photoIds = (user.photos || []).map((p) => p.publicId);
  const selfieId = user.selfiePhoto?.publicId;

  // Count what we're about to delete — used to populate cascadeSummary on
  // the DeletionRequest row below. Counts run BEFORE the cascade so a
  // partial transaction failure doesn't corrupt the summary.
  const [
    matchCount,
    likeFromCount,
    likeToCount,
    blockCount,
    reportFromCount,
  ] = await Promise.all([
    Match.countDocuments({ users: userId }),
    Like.countDocuments({ fromUser: userId }),
    Like.countDocuments({ toUser: userId }),
    Block.countDocuments({ $or: [{ blocker: userId }, { blocked: userId }] }),
    Report.countDocuments({ reporter: userId }),
  ]);

  const messageCount = matchCount > 0
    ? await Message.countDocuments({
      matchId: { $in: (await Match.find({ users: userId }, { _id: 1 })).map((m) => m._id) },
    })
    : 0;

  const cascadeSummary = {
    matches: matchCount,
    messages: messageCount,
    likesSent: likeFromCount,
    likesReceived: likeToCount,
    blocks: blockCount,
    reports: reportFromCount,
    photos: photoIds.length + (selfieId ? 1 : 0),
  };

  await withTransaction(async (session) => {
    const opts = sessionOpt(session);

    // Find matches inside the transaction so child message deletes see them.
    const matches = await Match.find({ users: userId }, { _id: 1 }, opts);
    const matchIds = matches.map((m) => m._id);

    if (matchIds.length > 0) {
      await Message.deleteMany({ matchId: { $in: matchIds } }, opts);
    }
    await Match.deleteMany({ users: userId }, opts);
    await Like.deleteMany(
      { $or: [{ fromUser: userId }, { toUser: userId }] },
      opts,
    );
    await Block.deleteMany(
      { $or: [{ blocker: userId }, { blocked: userId }] },
      opts,
    );
    await Report.deleteMany({ reporter: userId }, opts);

    // User doc last so the cascades all see a valid owner.
    await User.deleteOne({ _id: userId }, opts);
  });

  // Phase 1.17 — write the audit row AFTER the user row is gone so we
  // never have both rows alive together. Stored without a TTL — operators
  // can prune manually if retention policy ever requires it.
  try {
    await DeletionRequest.create({
      userId,
      userEmail,
      requesterIp: ctx.requesterIp || null,
      cascadeSummary,
    });
  } catch (auditErr) {
    // Don't fail the user-facing request on audit-row failure — the
    // cascade is already complete. Log loudly so this can be reconciled
    // by the operator.
    logger.error(
      {
        event: 'account.delete.audit_failed',
        userId: String(userId),
        err: auditErr.message,
      },
      'Failed to write DeletionRequest audit row',
    );
  }

  // Disconnect any open sockets for this user. Done AFTER the DB cascades and
  // BEFORE returning so the next request from the device can't sneak in. We
  // call disconnect(true) without awaiting — sockets tear down on next tick.
  if (io) {
    try {
      const sockets = await io.in(String(userId)).fetchSockets();
      sockets.forEach((s) => s.disconnect(true));
    } catch (err) {
      logger.warn({ err: err.message, userId }, 'Failed to disconnect user sockets');
    }
  }

  // Best-effort Cloudinary cleanup AFTER mongo is consistent. Phase 1.2:
  // failures are now persisted to `PendingImageDelete` for the reaper.
  await Promise.all(
    [...photoIds, selfieId]
      .filter(Boolean)
      .map(async (publicId) => {
        try {
          await deleteImage(publicId);
        } catch (err) {
          try {
            await PendingImageDelete.updateOne(
              { publicId },
              {
                $setOnInsert: {
                  publicId,
                  nextAttemptAt: new Date(Date.now() + 60 * 1000),
                },
                $set: { lastError: String(err.message || err).slice(0, 500) },
              },
              { upsert: true },
            );
            logger.warn(
              { event: 'media.delete.deferred', publicId, err: err.message },
              'Failed to delete image during account deletion; queued for reaper',
            );
          } catch (persistErr) {
            logger.error(
              {
                event: 'media.delete.deferred.persist_failed',
                publicId,
                err: persistErr.message,
              },
              'Asset orphaned during account deletion',
            );
          }
        }
      }),
  );

  // Best-effort cache invalidation.
  await Promise.all([
    cacheDelPattern(`feed:${userId}:*`),
    cacheDelPattern(`exclude:${userId}*`),
    cacheDelPattern(`ideal:${userId}:*`),
  ]);

  logger.info({ userId, cascadeSummary }, 'Account deleted');

  return { message: 'Account deleted successfully' };
};

/**
 * Phase 1.17 — GDPR data export.
 *
 * Build a JSON document of the authenticated user's full data:
 *   - profile  (the User doc minus refresh tokens / FCM tokens / selfie hash)
 *   - photos   (URLs and publicIds only — we don't re-upload the binaries)
 *   - matches  (id, partner id, createdAt, lastMessage timestamp)
 *   - messages (the messages the user SENT — receiving the other side's
 *     messages would expose chat history of a different user without their
 *     consent. GDPR Article 15 right of access is to the data ABOUT the
 *     subject, which is the message ABOUT the subject = the messages they
 *     wrote.)
 *   - likes    (sent + received — receiver IDs are PII but they're
 *     consequences of the user's actions, so we include them.)
 *   - boost    (current boost level + expiry, which is all we store)
 *
 * Returned as an in-memory JSON object. The controller streams it to the
 * client as application/json. ZIP packaging is intentionally NOT done in v1
 * — JSON is enough, and a client-side ZIP is trivial if desired.
 *
 * Performance note: at our scale (sub-50k messages per heavy user) loading
 * everything into memory is fine. If a power user exports 500k messages
 * we'll want to switch to a streamed JSON-lines response.
 */
const exportAccountData = async (userId) => {
  const user = await User.findById(userId).select('-refreshToken -refreshSessions -fcmTokens -__v');
  if (!user) throw new AppError('User not found', 404);

  const matches = await Match.find({ users: userId }).lean();
  const matchIds = matches.map((m) => m._id);

  const [messagesSent, likesSent, likesReceived] = await Promise.all([
    matchIds.length > 0
      ? Message.find({
        matchId: { $in: matchIds },
        sender: userId,
      }).lean()
      : [],
    Like.find({ fromUser: userId }).lean(),
    Like.find({ toUser: userId }).lean(),
  ]);

  const profile = user.toObject();
  // Strip the selfie hash explicitly — it's not in the user-facing schema
  // and could be used to re-link the user across accounts.
  delete profile.selfiePhoto;

  return {
    exportedAt: new Date().toISOString(),
    schemaVersion: 1,
    profile,
    photos: (user.photos || []).map((p) => ({
      url: p.url,
      publicId: p.publicId,
    })),
    matches: matches.map((m) => ({
      _id: String(m._id),
      users: (m.users || []).map(String),
      createdAt: m.createdAt,
      lastMessageAt: m.lastMessage ? m.lastMessage.createdAt : null,
    })),
    messagesSent: messagesSent.map((m) => ({
      _id: String(m._id),
      matchId: String(m.matchId),
      text: m.text,
      createdAt: m.createdAt,
    })),
    likesSent: likesSent.map((l) => ({
      _id: String(l._id),
      toUser: String(l.toUser),
      status: l.status,
      createdAt: l.createdAt,
    })),
    likesReceived: likesReceived.map((l) => ({
      _id: String(l._id),
      fromUser: String(l.fromUser),
      status: l.status,
      createdAt: l.createdAt,
    })),
    boost: {
      level: user.boostLevel,
      expiry: user.boostExpiry,
    },
  };
};

module.exports = { deleteAccount, exportAccountData };
