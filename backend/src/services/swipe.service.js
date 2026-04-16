const mongoose = require('mongoose');
const User = require('../models/User');
const Like = require('../models/Like');
const Block = require('../models/Block');
const AppError = require('../utils/AppError');
const { sendPush } = require('./notification.service');
const { cacheGet, cacheSet, cacheDel } = require('../utils/cache');

const BOOST_SCORES = {
  gold: 1000,
  silver: 500,
  bronze: 200,
  none: 0,
};

const getAutoBoostTier = (daysWithoutMatch) => {
  if (daysWithoutMatch >= 25) return 'gold';
  if (daysWithoutMatch >= 15) return 'silver';
  if (daysWithoutMatch >= 7) return 'bronze';
  return 'none';
};

const getEffectiveBoost = (user) => {
  if (user.boostExpiry && user.boostExpiry > new Date() && user.boostLevel !== 'none') {
    return user.boostLevel;
  }
  return getAutoBoostTier(user.daysWithoutMatch);
};

const FEED_CACHE_TTL = 120; // 2 minutes
const EXCLUDE_IDS_CACHE_TTL = 300; // 5 minutes — excluded IDs change less frequently

const getFeed = async (userId, cursor, limit = 20) => {
  // Try cache first (only for first page with no cursor)
  if (!cursor) {
    const cacheKey = `feed:${userId}:${limit}`;
    const cached = await cacheGet(cacheKey);
    if (cached) return cached;
  }

  const girl = await User.findById(userId).select('location preferences').lean();
  if (!girl) throw new AppError('User not found', 404);

  // Cache excluded IDs separately (5 min TTL) — saves 2 queries per feed request
  const excludeCacheKey = `exclude:${userId}`;
  let excludeIds;
  const cachedExclude = await cacheGet(excludeCacheKey);

  if (cachedExclude) {
    excludeIds = cachedExclude.map((id) => new mongoose.Types.ObjectId(id));
  } else {
    const [interactedIds, blockedIds] = await Promise.all([
      Like.find({ fromUser: userId }).distinct('toUser'),
      Block.find({
        $or: [{ blocker: userId }, { blocked: userId }],
      }).then((blocks) =>
        blocks.map((b) =>
          b.blocker.toString() === userId.toString() ? b.blocked : b.blocker
        )
      ),
    ]);

    const excludeStringIds = [
      ...new Set([
        ...interactedIds.map((id) => id.toString()),
        ...blockedIds.map((id) => id.toString()),
        userId.toString(),
      ]),
    ];

    await cacheSet(excludeCacheKey, excludeStringIds, EXCLUDE_IDS_CACHE_TTL);
    excludeIds = excludeStringIds.map((id) => new mongoose.Types.ObjectId(id));
  }

  const { ageMin, ageMax, maxDistance } = girl.preferences;

  const pipeline = [];

  // Geo filter if girl has location
  if (
    girl.location?.coordinates &&
    girl.location.coordinates[0] !== 0 &&
    girl.location.coordinates[1] !== 0
  ) {
    pipeline.push({
      $geoNear: {
        near: {
          type: 'Point',
          coordinates: girl.location.coordinates,
        },
        distanceField: 'distance',
        maxDistance: (maxDistance || 50) * 1000,
        spherical: true,
        query: {
          _id: { $nin: excludeIds },
          gender: 'male',
          isActive: true,
          isProfileComplete: true,
          age: { $gte: ageMin || 18, $lte: ageMax || 50 },
        },
      },
    });
  } else {
    pipeline.push({
      $match: {
        _id: { $nin: excludeIds },
        gender: 'male',
        isActive: true,
        isProfileComplete: true,
        age: { $gte: ageMin || 18, $lte: ageMax || 50 },
      },
    });
  }

  // Add boost score for ranking
  pipeline.push({
    $addFields: {
      effectiveBoost: {
        $cond: {
          if: {
            $and: [
              { $ne: ['$boostLevel', 'none'] },
              { $gt: ['$boostExpiry', new Date()] },
            ],
          },
          then: '$boostLevel',
          else: {
            $switch: {
              branches: [
                { case: { $gte: ['$daysWithoutMatch', 25] }, then: 'gold' },
                { case: { $gte: ['$daysWithoutMatch', 15] }, then: 'silver' },
                { case: { $gte: ['$daysWithoutMatch', 7] }, then: 'bronze' },
              ],
              default: 'none',
            },
          },
        },
      },
    },
  });

  pipeline.push({
    $addFields: {
      boostScore: {
        $switch: {
          branches: [
            { case: { $eq: ['$effectiveBoost', 'gold'] }, then: BOOST_SCORES.gold },
            { case: { $eq: ['$effectiveBoost', 'silver'] }, then: BOOST_SCORES.silver },
            { case: { $eq: ['$effectiveBoost', 'bronze'] }, then: BOOST_SCORES.bronze },
          ],
          default: BOOST_SCORES.none,
        },
      },
    },
  });

  // Cursor-based pagination
  if (cursor) {
    pipeline.push({
      $match: {
        _id: { $lt: new mongoose.Types.ObjectId(cursor) },
      },
    });
  }

  // Sort by boost priority, then daysWithoutMatch, then newest
  pipeline.push({ $sort: { boostScore: -1, daysWithoutMatch: -1, _id: -1 } });
  pipeline.push({ $limit: limit });

  // Project only needed fields
  pipeline.push({
    $project: {
      name: 1,
      age: 1,
      bio: 1,
      interests: 1,
      photos: 1,
      location: { city: 1, state: 1 },
      effectiveBoost: 1,
      distance: 1,
    },
  });

  const profiles = await User.aggregate(pipeline).option({ maxTimeMS: 10000 });

  const nextCursor =
    profiles.length === limit
      ? profiles[profiles.length - 1]._id.toString()
      : null;

  const result = { profiles, nextCursor };

  // Cache first page results
  if (!cursor) {
    const cacheKey = `feed:${userId}:${limit}`;
    await cacheSet(cacheKey, result, FEED_CACHE_TTL);
  }

  return result;
};

const like = async (fromUserId, toUserId) => {
  if (fromUserId.toString() === toUserId) {
    throw new AppError('Cannot like yourself', 400);
  }

  const toUser = await User.findById(toUserId);
  if (!toUser || toUser.gender !== 'male') {
    throw new AppError('User not found', 404);
  }

  try {
    await Like.create({
      fromUser: fromUserId,
      toUser: toUserId,
      status: 'pending',
    });
  } catch (err) {
    if (err.code === 11000) {
      throw new AppError('Already liked this user', 409);
    }
    throw err;
  }

  // Invalidate caches
  await Promise.all([
    cacheDel(`feed:${fromUserId}:20`),
    cacheDel(`exclude:${fromUserId}`),
  ]);

  // Push notification to the boy
  sendPush(toUserId, 'New Like!', 'Someone liked your profile', {
    type: 'new_like',
  });

  return { message: 'Like sent' };
};

const skip = async (fromUserId, toUserId) => {
  if (fromUserId.toString() === toUserId) {
    throw new AppError('Cannot skip yourself', 400);
  }

  try {
    await Like.create({
      fromUser: fromUserId,
      toUser: toUserId,
      status: 'skipped',
    });
  } catch (err) {
    if (err.code === 11000) {
      return { message: 'Skipped' };
    }
    throw err;
  }

  // Invalidate caches
  await Promise.all([
    cacheDel(`feed:${fromUserId}:20`),
    cacheDel(`exclude:${fromUserId}`),
  ]);

  return { message: 'Skipped' };
};

/**
 * Undo the last skip — deletes the most recent 'skipped' like from this user.
 * Only allows undoing skips (not likes, to prevent gaming the system).
 */
const undoLastSkip = async (userId) => {
  const lastSkip = await Like.findOne({
    fromUser: userId,
    status: 'skipped',
  }).sort({ createdAt: -1 });

  if (!lastSkip) {
    throw new AppError('No recent skip to undo', 404);
  }

  // Only allow undo within 5 minutes
  const fiveMinutesAgo = new Date(Date.now() - 5 * 60 * 1000);
  if (lastSkip.createdAt < fiveMinutesAgo) {
    throw new AppError('Skip too old to undo (max 5 minutes)', 400);
  }

  await Like.findByIdAndDelete(lastSkip._id);

  // Invalidate caches so the profile reappears
  await Promise.all([
    cacheDel(`feed:${userId}:20`),
    cacheDel(`exclude:${userId}`),
  ]);

  return { message: 'Skip undone', undoneUserId: lastSkip.toUser.toString() };
};

module.exports = { getFeed, like, skip, undoLastSkip, getEffectiveBoost, getAutoBoostTier };
