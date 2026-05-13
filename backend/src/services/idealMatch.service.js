const mongoose = require('mongoose');
const User = require('../models/User');
const Like = require('../models/Like');
const Block = require('../models/Block');
const Match = require('../models/Match');
const AppError = require('../utils/AppError');
const { cacheGet, cacheSet } = require('../utils/cache');
const { USER_PROJECTION } = require('../utils/userProjection');

// -------- Categorical taxonomies (one-hot) --------
const GENDERS = ['male', 'female', 'nonbinary'];
const DATING_INTENTIONS = [
  'life_partner',
  'long_term',
  'long_term_open_short',
  'short_term_open_long',
  'short_term',
  'new_friends',
  'figuring_out',
];
const RELATIONSHIP_TYPES = [
  'monogamy',
  'non_monogamy',
  'open_to_exploring',
  'prefer_not_to_say',
];
const EXERCISE = ['active', 'sometimes', 'never', 'prefer_not_to_say'];
const CHILDREN = ['have', 'dont_have', 'prefer_not_to_say'];
const FAMILY_PLANS = ['want', 'dont_want', 'open', 'not_sure', 'prefer_not_to_say'];
const RELIGIONS = [
  'Hindu',
  'Muslim',
  'Christian',
  'Jewish',
  'Buddhist',
  'Sikh',
  'Atheist',
  'Spiritual',
  'Other',
];
const POLITICS = ['left', 'center_left', 'center', 'center_right', 'right'];
const VICE_VALUES = ['yes', 'sometimes', 'rarely', 'no', 'prefer_not_to_say'];

// Top-N multi-hot dictionaries — kept short for v1 scale.
const TOP_INTERESTS = [
  'Travel', 'Cooking', 'Reading', 'Music', 'Movies', 'Fitness', 'Yoga', 'Hiking',
  'Photography', 'Art', 'Dancing', 'Gaming', 'Coffee', 'Wine', 'Food', 'Fashion',
  'Sports', 'Pets', 'Beach', 'Coding', 'Writing', 'Theatre', 'Concerts',
  'Running', 'Cycling', 'Swimming', 'Volunteering', 'Meditation', 'Podcasts',
  'Astrology',
];
const TOP_LANGUAGES = [
  'English', 'Hindi', 'Spanish', 'Mandarin', 'French', 'Arabic', 'Portuguese',
  'Bengali', 'Russian', 'Japanese',
];

// Per-feature weights — applied per-block, not per-dimension, so blocks with
// more dimensions are not over-weighted just by sheer width.
const WEIGHTS = {
  datingIntentions: 3,
  interests: 2,
  vices: 1,
  default: 1,
};

const FEATURE_CACHE_TTL = 24 * 60 * 60; // 24h per spec §11.

// -------- Encoding helpers --------
const oneHot = (value, taxonomy) => taxonomy.map((v) => (v === value ? 1 : 0));
const multiHot = (values, taxonomy) => {
  const set = new Set((values || []).map((v) => String(v)));
  return taxonomy.map((v) => (set.has(v) ? 1 : 0));
};
const normalize = (val, min, max) => {
  if (val === undefined || val === null || Number.isNaN(val)) return 0;
  const clamped = Math.max(min, Math.min(max, val));
  return (clamped - min) / (max - min);
};

const haversineKm = (a, b) => {
  if (!a || !b || a.length !== 2 || b.length !== 2) return 200;
  const [lon1, lat1] = a;
  const [lon2, lat2] = b;
  if (
    (lon1 === 0 && lat1 === 0)
    || (lon2 === 0 && lat2 === 0)
  ) return 200;
  const R = 6371;
  const toRad = (d) => (d * Math.PI) / 180;
  const dLat = toRad(lat2 - lat1);
  const dLon = toRad(lon2 - lon1);
  const x = Math.sin(dLat / 2) ** 2
    + Math.cos(toRad(lat1)) * Math.cos(toRad(lat2)) * Math.sin(dLon / 2) ** 2;
  return 2 * R * Math.asin(Math.sqrt(x));
};

/**
 * Encode a user into a fixed-length feature vector. Each block of the vector
 * receives a multiplier (WEIGHTS) so that strongly-weighted dimensions
 * dominate the cosine similarity per the spec recipe.
 *
 * Returns a plain Array<number>.
 */
const encodeUser = (user, viewerLocation) => {
  const v = [];
  const push = (arr, weight = WEIGHTS.default) => {
    arr.forEach((x) => v.push(x * weight));
  };

  // Categorical one-hot
  push(oneHot(user.gender, GENDERS));
  push(oneHot(user.datingIntentions, DATING_INTENTIONS), WEIGHTS.datingIntentions);
  push(oneHot(user.relationshipType, RELATIONSHIP_TYPES));
  push(oneHot(user.exercise, EXERCISE));
  push(oneHot(user.children, CHILDREN));
  push(oneHot(user.familyPlans, FAMILY_PLANS));
  push(oneHot(user.religion, RELIGIONS));
  push(oneHot(user.politics, POLITICS));

  // Vices — each sub-field is its own one-hot block
  push(oneHot(user.vices?.drinking, VICE_VALUES), WEIGHTS.vices);
  push(oneHot(user.vices?.smoking, VICE_VALUES), WEIGHTS.vices);
  push(oneHot(user.vices?.marijuana, VICE_VALUES), WEIGHTS.vices);
  push(oneHot(user.vices?.drugs, VICE_VALUES), WEIGHTS.vices);

  // Numeric normalized
  v.push(normalize(user.age, 18, 65));
  v.push(normalize(user.height, 140, 210));
  const dKm = viewerLocation
    ? haversineKm(viewerLocation, user.location?.coordinates)
    : 0;
  v.push(1 - normalize(dKm, 0, 200)); // closer = higher score

  // Multi-hot
  push(multiHot(user.interests, TOP_INTERESTS), WEIGHTS.interests);
  push(multiHot(user.languages, TOP_LANGUAGES));

  return v;
};

const dot = (a, b) => {
  let s = 0;
  for (let i = 0; i < a.length; i++) s += a[i] * b[i];
  return s;
};

const norm = (a) => {
  let s = 0;
  for (let i = 0; i < a.length; i++) s += a[i] * a[i];
  return Math.sqrt(s);
};

const cosineSim = (a, b) => {
  const denom = norm(a) * norm(b);
  if (denom === 0) return 0;
  const sim = dot(a, b) / denom;
  // Clamp to [0, 1] per spec — encodings here are non-negative so negative
  // cosines shouldn't occur, but guard anyway.
  return Math.max(0, Math.min(1, sim));
};

// -------- Commonalities (human-readable) --------
const formatIntent = (i) => {
  const map = {
    life_partner: 'a life partner',
    long_term: 'a long-term relationship',
    long_term_open_short: 'long-term but open to short-term',
    short_term_open_long: 'short-term but open to long-term',
    short_term: 'something short-term',
    new_friends: 'new friends',
    figuring_out: 'figuring it out',
  };
  return map[i] || i;
};

const computeCommonalities = (me, them) => {
  const out = [];

  if (
    me.datingIntentions
    && them.datingIntentions
    && me.datingIntentions === them.datingIntentions
  ) {
    out.push(`Both want ${formatIntent(me.datingIntentions)}`);
  }

  if (me.relationshipType && them.relationshipType && me.relationshipType === them.relationshipType) {
    out.push(`Both prefer ${me.relationshipType.replace(/_/g, ' ')}`);
  }

  const sharedLangs = (me.languages || []).filter((l) => (them.languages || []).includes(l));
  if (sharedLangs.length >= 1) {
    out.push(`Both speak ${sharedLangs.join(' & ')}`);
  }

  const sharedInterests = (me.interests || []).filter((i) => (them.interests || []).includes(i));
  if (sharedInterests.length > 0) {
    out.push(`Shared interests: ${sharedInterests.slice(0, 4).join(', ')}`);
  }

  if (me.children && them.children && me.children === them.children) {
    if (me.children === 'have') out.push('Both have kids');
    else if (me.children === 'dont_have') out.push('Neither has kids');
  }

  if (me.familyPlans && them.familyPlans && me.familyPlans === them.familyPlans) {
    if (me.familyPlans === 'want') out.push('Both want kids someday');
    else if (me.familyPlans === 'dont_want') out.push('Neither wants kids');
  }

  if (me.religion && them.religion && me.religion === them.religion) {
    out.push(`Both are ${me.religion}`);
  }

  if (me.exercise && them.exercise && me.exercise === them.exercise && me.exercise !== 'prefer_not_to_say') {
    out.push(`Both are ${me.exercise} with exercise`);
  }

  return out;
};

/**
 * Resolve which genders to consider, per the viewer's preferences.
 */
const resolveTargetGenders = (viewer) => {
  const pref = viewer.preferences?.genderPreference;
  if (pref === 'men') return ['male'];
  if (pref === 'women') return ['female'];
  if (pref === 'everyone') return ['male', 'female', 'nonbinary'];
  // Default: opposite gender
  if (viewer.gender === 'female') return ['male'];
  if (viewer.gender === 'male') return ['female'];
  return ['male', 'female', 'nonbinary'];
};

/**
 * Compute the ideal match for `userId`.
 * Returns { topMatch, score, alternates, commonalities }.
 */
const getIdealMatch = async (userId, limit = 5) => {
  const cacheKey = `ideal:${userId}:${limit}`;
  const cached = await cacheGet(cacheKey);
  if (cached) return cached;

  const viewer = await User.findById(userId).lean();
  if (!viewer) throw new AppError('User not found', 404);

  const targetGenders = resolveTargetGenders(viewer);

  // Build the exclusion set: already matched/liked/skipped, blocked.
  const [interacted, blocks, existingMatches] = await Promise.all([
    Like.find({ fromUser: userId }).distinct('toUser'),
    Block.find({ $or: [{ blocker: userId }, { blocked: userId }] }).lean(),
    Match.find({ users: userId }).distinct('users'),
  ]);

  const excludeSet = new Set([userId.toString()]);
  interacted.forEach((id) => excludeSet.add(id.toString()));
  blocks.forEach((b) => {
    excludeSet.add(b.blocker.toString());
    excludeSet.add(b.blocked.toString());
  });
  existingMatches.forEach((id) => excludeSet.add(id.toString()));

  const excludeIds = [...excludeSet].map((id) => new mongoose.Types.ObjectId(id));

  // Candidate filter — gender, active, profile-complete, within max distance.
  const maxDistanceKm = viewer.preferences?.maxDistance ?? 200;
  const candidateFilter = {
    _id: { $nin: excludeIds },
    gender: { $in: targetGenders },
    isActive: true,
    isProfileComplete: true,
  };

  // Use $geoNear when possible for an efficient pre-filter. Missing or
  // legacy [0,0] coordinates count as "no location" (see fix 30).
  let candidates;
  const viewerCoords = viewer.location?.coordinates;
  const hasViewerLocation = Array.isArray(viewerCoords)
    && viewerCoords.length === 2
    && !(viewerCoords[0] === 0 && viewerCoords[1] === 0);
  if (hasViewerLocation) {
    candidates = await User.aggregate([
      {
        $geoNear: {
          near: { type: 'Point', coordinates: viewerCoords },
          distanceField: 'distance',
          maxDistance: maxDistanceKm * 1000,
          spherical: true,
          query: candidateFilter,
        },
      },
      { $project: { ...USER_PROJECTION, distance: 1 } },
      { $limit: 500 }, // hard cap — v1 scale guard
    ]);
  } else {
    candidates = await User.find(candidateFilter)
      .select(USER_PROJECTION)
      .limit(500)
      .lean();
  }

  if (candidates.length === 0) {
    throw new AppError('No ideal match yet — keep building your profile', 404);
  }

  // Score every candidate.
  const meVec = encodeUser(viewer, viewer.location?.coordinates);
  const scored = candidates.map((c) => ({
    user: c,
    score: cosineSim(meVec, encodeUser(c, viewer.location?.coordinates)),
  }));
  scored.sort((a, b) => b.score - a.score);

  const top = scored[0];
  const alternates = scored.slice(1, limit).map((s) => ({
    user: s.user,
    score: Number(s.score.toFixed(4)),
  }));

  const result = {
    topMatch: top.user,
    score: Number(top.score.toFixed(4)),
    alternates,
    commonalities: computeCommonalities(viewer, top.user),
  };

  // 24h cache per spec §11. Cache invalidation hooks live in profile.service
  // (updateProfile) and queue.service (accept) — both invalidate the user's
  // ideal-match cache through this module's helper below.
  await cacheSet(cacheKey, result, FEATURE_CACHE_TTL);

  return result;
};

const invalidateIdealMatch = async (userId) => {
  // We don't know which `limit` keys are cached — bust the common ones.
  const { cacheDelPattern } = require('../utils/cache');
  await cacheDelPattern(`ideal:${userId}:*`);
};

module.exports = { getIdealMatch, invalidateIdealMatch };
