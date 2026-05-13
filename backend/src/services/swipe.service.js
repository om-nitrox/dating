const mongoose = require('mongoose');
const User = require('../models/User');
const Like = require('../models/Like');
const Block = require('../models/Block');
const AppError = require('../utils/AppError');
const { sendPush } = require('./notification.service');
const {
  cacheGet, cacheSet, getCacheVersion, bumpCacheVersion,
} = require('../utils/cache');

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

const getFeed = async (userId, cursor, limit = 20, filters = {}) => {
  // Try cache first (only for first page with no cursor and default filters).
  // Any user-supplied filter bypasses the cache so the response isn't
  // accidentally pinned to a previous request's filter set.
  const hasFilters = filters
    && (filters.minAge !== undefined
      || filters.maxAge !== undefined
      || filters.maxDistanceKm !== undefined
      || filters.intent);

  // Versioned cache key — bumped on like/skip/profile location change. This
  // means we never need pattern-deletes for feed/exclude (which previously
  // raced and missed concurrent writers); a bump just makes the next read
  // miss and recompute.
  const feedVer = await getCacheVersion('feed', userId);
  const excludeVer = await getCacheVersion('exclude', userId);

  if (!cursor && !hasFilters) {
    const cacheKey = `feed:${userId}:${feedVer}:${limit}`;
    const cached = await cacheGet(cacheKey);
    if (cached) return cached;
  }

  const girl = await User.findById(userId).select('location preferences gender').lean();
  if (!girl) throw new AppError('User not found', 404);

  // Cache excluded IDs separately (5 min TTL) — saves 2 queries per feed request
  const excludeCacheKey = `exclude:${userId}:${excludeVer}`;
  let excludeIds;
  const cachedExclude = await cacheGet(excludeCacheKey);

  if (cachedExclude) {
    excludeIds = cachedExclude.map((id) => new mongoose.Types.ObjectId(id));
  } else {
    const [interactedIds, blockedIds] = await Promise.all([
      Like.find({ fromUser: userId }).distinct('toUser'),
      Block.find({
        $or: [{ blocker: userId }, { blocked: userId }],
      }).then((blocks) => blocks.map((b) => (b.blocker.toString() === userId.toString() ? b.blocked : b.blocker))),
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

  const { ageMin, ageMax, maxDistance } = girl.preferences || {};

  // Resolve filters — request query params override the saved preferences,
  // per BACKEND_API.md §3.
  const effMinAge = filters.minAge ?? ageMin ?? 18;
  const effMaxAge = filters.maxAge ?? ageMax ?? 99;
  const effMaxKm = filters.maxDistanceKm ?? maxDistance ?? 50;

  // Resolve target gender set from preferences.genderPreference.
  // 'men' → ['male'], 'women' → ['female'], 'everyone' → all.
  // Spec §3: "opposite gender (or per `preferences.genderPreference`)".
  let targetGenders;
  const genderPref = girl.preferences?.genderPreference;
  if (genderPref === 'men') targetGenders = ['male'];
  else if (genderPref === 'women') targetGenders = ['female'];
  else if (genderPref === 'everyone') targetGenders = ['male', 'female', 'nonbinary'];
  else if (girl.gender === 'female') targetGenders = ['male']; // default: opposite
  else if (girl.gender === 'male') targetGenders = ['female'];
  else targetGenders = ['male', 'female', 'nonbinary'];

  const baseMatch = {
    _id: { $nin: excludeIds },
    gender: { $in: targetGenders },
    isActive: true,
    isProfileComplete: true,
    age: { $gte: effMinAge, $lte: effMaxAge },
  };

  if (filters.intent) {
    baseMatch.datingIntentions = filters.intent;
  }

  const pipeline = [];

  // Geo filter if girl has a real location. We treat missing coordinates AND
  // legacy [0,0] sentinels (from before fix 30 changed the default) as "no
  // location set" so we don't $geoNear against the Gulf of Guinea.
  const girlCoords = girl.location?.coordinates;
  const hasGirlLocation = Array.isArray(girlCoords)
    && girlCoords.length === 2
    && !(girlCoords[0] === 0 && girlCoords[1] === 0);
  if (hasGirlLocation) {
    pipeline.push({
      $geoNear: {
        near: {
          type: 'Point',
          coordinates: girlCoords,
        },
        distanceField: 'distance',
        maxDistance: effMaxKm * 1000,
        spherical: true,
        query: baseMatch,
      },
    });
  } else {
    pipeline.push({ $match: baseMatch });
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

  // Sort by _id DESC only so cursor-based pagination is well-defined.
  // Boost still influences the feed: we keep `effectiveBoost`/`boostScore`
  // on each profile so the client (and future server-side reranker) can
  // surface boosted candidates. Earlier code sorted by boostScore first,
  // which silently broke `{_id: $lt: cursor}` pagination because the cursor
  // is monotonic in _id but not in boostScore. See fix 16 in the readiness
  // review.
  pipeline.push({ $sort: { _id: -1 } });
  pipeline.push({ $limit: limit });

  // Project the full UserModel-compatible subset.
  // Private fields (refreshToken, selfiePhoto, email, fcmTokens, dob) are
  // never projected to viewers — only public profile fields go on the cards.
  pipeline.push({
    $project: {
      _id: 1,
      name: 1,
      age: 1,
      gender: 1,
      pronouns: 1,
      orientation: 1,
      bio: 1,
      interests: 1,
      photos: 1,
      prompts: 1,
      height: 1,
      ethnicity: 1,
      hometown: 1,
      jobTitle: 1,
      workplace: 1,
      education: 1,
      religion: 1,
      politics: 1,
      languages: 1,
      datingIntentions: 1,
      relationshipType: 1,
      children: 1,
      familyPlans: 1,
      vices: 1,
      isVerified: 1,
      boostLevel: 1,
      daysWithoutMatch: 1,
      location: { city: 1, state: 1 },
      effectiveBoost: 1,
      distance: 1,
    },
  });

  const profiles = await User.aggregate(pipeline).option({ maxTimeMS: 10000 });

  const nextCursor = profiles.length === limit
    ? profiles[profiles.length - 1]._id.toString()
    : null;

  const result = { profiles, nextCursor };

  // Cache first page results (only when no user-supplied filters).
  if (!cursor && !hasFilters) {
    const cacheKey = `feed:${userId}:${feedVer}:${limit}`;
    await cacheSet(cacheKey, result, FEED_CACHE_TTL);
  }

  return result;
};

const like = async (fromUserId, toUserId) => {
  if (fromUserId.toString() === toUserId) {
    throw new AppError('Cannot like yourself', 400);
  }

  const toUser = await User.findById(toUserId);
  if (!toUser) {
    throw new AppError('User not found', 404);
  }
  if (toUser.gender !== 'male') {
    // Recipient exists but cannot be liked in the reverse-match flow.
    // 400 NOT_LIKEABLE distinguishes this from a genuine 404.
    throw new AppError('User cannot be liked', 400, 'NOT_LIKEABLE');
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

  // Bump versioned caches — any past key is now stale and will miss on read.
  await Promise.all([
    bumpCacheVersion('feed', fromUserId),
    bumpCacheVersion('exclude', fromUserId),
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

  // Bump versioned caches.
  await Promise.all([
    bumpCacheVersion('feed', fromUserId),
    bumpCacheVersion('exclude', fromUserId),
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

  // Bump versioned caches so the un-skipped profile reappears in the feed.
  await Promise.all([
    bumpCacheVersion('feed', userId),
    bumpCacheVersion('exclude', userId),
  ]);

  return { message: 'Skip undone', undoneUserId: lastSkip.toUser.toString() };
};

module.exports = {
  getFeed, like, skip, undoLastSkip, getEffectiveBoost, getAutoBoostTier,
};
