const User = require('../models/User');
const Like = require('../models/Like');
const Match = require('../models/Match');
const Message = require('../models/Message');
const Block = require('../models/Block');
const Report = require('../models/Report');
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
 */
const deleteAccount = async (userId, io) => {
  const user = await User.findById(userId);
  if (!user) throw new AppError('User not found', 404);

  // Capture publicIds before the DB doc is deleted so we can reap them after.
  const photoIds = (user.photos || []).map((p) => p.publicId);
  const selfieId = user.selfiePhoto?.publicId;

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

  // Best-effort Cloudinary cleanup AFTER mongo is consistent.
  await Promise.all(
    [...photoIds, selfieId]
      .filter(Boolean)
      .map((publicId) => deleteImage(publicId).catch((err) => {
        logger.warn({ publicId, err: err.message }, 'Failed to delete image during account deletion');
      })),
  );

  // Best-effort cache invalidation.
  await Promise.all([
    cacheDelPattern(`feed:${userId}:*`),
    cacheDelPattern(`exclude:${userId}*`),
    cacheDelPattern(`ideal:${userId}:*`),
  ]);

  logger.info({ userId }, 'Account deleted');

  return { message: 'Account deleted successfully' };
};

module.exports = { deleteAccount };
