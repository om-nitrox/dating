const mongoose = require('mongoose');
const Like = require('../models/Like');
const Match = require('../models/Match');
const User = require('../models/User');
const AppError = require('../utils/AppError');
const logger = require('../utils/logger');
const { sendPush } = require('./notification.service');
const mlMatchClient = require('./mlMatch.client');
const { bumpCacheVersion } = require('../utils/cache');
const { USER_PROJECTION } = require('../utils/userProjection');
const withTransaction = require('../utils/withTransaction');
const { invalidateIdealMatch } = require('./idealMatch.service');
const { matchCreatedTotal } = require('../observability/metrics');

const sessionOpt = (session) => (session ? { session } : {});

/**
 * Spec §4: pending likes for the authenticated boy, sorted with boosted
 * users at the top (effective boost — including auto-boost from
 * daysWithoutMatch), then by createdAt DESC.
 *
 * Phase 0.3: now page-paginated. Spec contract is `{ likes, hasMore }`
 * with `page` (1-indexed) and `limit` (capped at 100, default 20).
 */
const getQueue = async (userId, page = 1, limit = 20) => {
  const objectUserId = new mongoose.Types.ObjectId(userId);
  // Defensive clamping — controllers should pre-validate, but never trust
  // a caller; the spec says `limit` <= 100.
  const safePage = Math.max(1, parseInt(page, 10) || 1);
  const safeLimit = Math.min(100, Math.max(1, parseInt(limit, 10) || 20));
  const skip = (safePage - 1) * safeLimit;

  const likes = await Like.aggregate([
    { $match: { toUser: objectUserId, status: 'pending' } },

    // Pull the sender's full UserModel projection
    {
      $lookup: {
        from: 'users',
        localField: 'fromUser',
        foreignField: '_id',
        pipeline: [{ $project: USER_PROJECTION }],
        as: 'fromUserDoc',
      },
    },
    { $unwind: { path: '$fromUserDoc', preserveNullAndEmptyArrays: false } },

    // Compute boost priority: explicit boost (still active) overrides auto.
    {
      $addFields: {
        effectiveBoost: {
          $cond: [
            {
              $and: [
                { $ne: ['$fromUserDoc.boostLevel', 'none'] },
                { $gt: ['$fromUserDoc.boostExpiry', new Date()] },
              ],
            },
            '$fromUserDoc.boostLevel',
            {
              $switch: {
                branches: [
                  { case: { $gte: ['$fromUserDoc.daysWithoutMatch', 25] }, then: 'gold' },
                  { case: { $gte: ['$fromUserDoc.daysWithoutMatch', 15] }, then: 'silver' },
                  { case: { $gte: ['$fromUserDoc.daysWithoutMatch', 7] }, then: 'bronze' },
                ],
                default: 'none',
              },
            },
          ],
        },
      },
    },
    {
      $addFields: {
        boostScore: {
          $switch: {
            branches: [
              { case: { $eq: ['$effectiveBoost', 'gold'] }, then: 3 },
              { case: { $eq: ['$effectiveBoost', 'silver'] }, then: 2 },
              { case: { $eq: ['$effectiveBoost', 'bronze'] }, then: 1 },
            ],
            default: 0,
          },
        },
      },
    },

    { $sort: { boostScore: -1, createdAt: -1 } },
    { $skip: skip },
    // Fetch one extra row so we can compute hasMore without a separate
    // countDocuments() — cheaper, race-free, and matches the pattern used
    // by match.service.getMatches.
    { $limit: safeLimit + 1 },

    // Final shape: LikeModel per spec §13
    {
      $project: {
        _id: 1,
        fromUser: '$fromUserDoc',
        status: 1,
        type: { $ifNull: ['$type', 'like'] },
        createdAt: 1,
      },
    },
  ]);

  const hasMore = likes.length > safeLimit;
  if (hasMore) likes.pop();

  return { likes, hasMore };
};

/**
 * Sort a pair of ObjectIds (or string ids) into a deterministic order so
 * `[u1, u2]` and `[u2, u1]` collapse to the same key. Used so the unique
 * compound index on Match enforces pair-uniqueness regardless of who liked first.
 */
const sortPair = (a, b) => {
  const aStr = a.toString();
  const bStr = b.toString();
  return aStr < bStr ? [a, b] : [b, a];
};

const accept = async (userId, likeId) => {
  const like = await Like.findById(likeId);

  if (!like) throw new AppError('Like not found', 404);
  if (like.toUser.toString() !== userId.toString()) {
    throw new AppError('Unauthorized', 403);
  }
  if (like.status !== 'pending') {
    throw new AppError('Like already processed', 400);
  }

  const [u1, u2] = sortPair(like.fromUser, like.toUser);

  // Wrap the multi-doc cascade in a transaction so a failure halfway through
  // (e.g., Match.create throws) doesn't leave Like.status=accepted with no
  // Match. Note Match.findOneAndUpdate+upsert protects against the race
  // where both sides try to upsert simultaneously (fix 12).
  const matchId = await withTransaction(async (session) => {
    const opts = sessionOpt(session);

    like.status = 'accepted';
    await like.save(opts);

    const upsertRes = await Match.findOneAndUpdate(
      { users: [u1, u2] },
      { $setOnInsert: { users: [u1, u2] } },
      {
        upsert: true,
        new: true,
        setDefaultsOnInsert: true,
        ...opts,
      },
    );

    // Reset daysWithoutMatch for BOTH users so they exit the boost ladder.
    await User.updateMany(
      { _id: { $in: [u1, u2] } },
      { $set: { daysWithoutMatch: 0 } },
      opts,
    );

    return upsertRes._id;
  });

  // Phase 0.9: bump the match-created counter once per accepted like.
  // Logged with the structured-event convention (match.created).
  matchCreatedTotal.inc();
  logger.info({ event: 'match.created', matchId: matchId.toString() }, 'match created');

  // Bump versioned caches for both participants (after commit) so a stale
  // feed/exclude entry never resurfaces a matched user.
  await Promise.all([
    bumpCacheVersion('feed', like.fromUser),
    bumpCacheVersion('feed', userId),
    bumpCacheVersion('exclude', like.fromUser),
    bumpCacheVersion('exclude', userId),
    invalidateIdealMatch(like.fromUser.toString()),
    invalidateIdealMatch(userId.toString()),
  ]);

  // Notify the girl that her like was accepted.
  sendPush(like.fromUser, "It's a Match!", 'Someone accepted your like!', {
    type: 'new_match',
    matchId: matchId.toString(),
  });

  // Feed mutual-match signal into the ML service for BOTH sides — the
  // match is the strongest positive signal we have, much stronger than a
  // one-sided like. Fire-and-forget on both ends.
  mlMatchClient.recordEvent(like.fromUser, userId, 'match');
  mlMatchClient.recordEvent(userId, like.fromUser, 'match');

  // Populate the match with the full UserModel projection for the response.
  const populated = await Match.aggregate([
    { $match: { _id: matchId } },
    {
      $lookup: {
        from: 'users',
        localField: 'users',
        foreignField: '_id',
        pipeline: [{ $project: USER_PROJECTION }],
        as: 'users',
      },
    },
    {
      $addFields: {
        lastMessage: null,
        unreadCount: 0,
      },
    },
  ]);

  return populated[0];
};

const reject = async (userId, likeId) => {
  const like = await Like.findById(likeId);

  if (!like) throw new AppError('Like not found', 404);
  if (like.toUser.toString() !== userId.toString()) {
    throw new AppError('Unauthorized', 403);
  }
  if (like.status !== 'pending') {
    throw new AppError('Like already processed', 400);
  }

  like.status = 'rejected';
  await like.save();

  // The boy rejected the girl's like — that's a negative signal toward
  // the girl's recommendation profile. We feed it from the girl's side
  // (her preference signal weakens; she'll see fewer similar boys).
  mlMatchClient.recordEvent(like.fromUser, userId, 'left_swipe');

  return {};
};

module.exports = { getQueue, accept, reject };
