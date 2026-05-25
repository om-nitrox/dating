const mongoose = require('mongoose');
const User = require('../models/User');
const Like = require('../models/Like');
const Block = require('../models/Block');
const Match = require('../models/Match');
const AppError = require('../utils/AppError');
const logger = require('../utils/logger');
const mlMatchClient = require('./mlMatch.client');
const { cacheGet, cacheSet } = require('../utils/cache');
const { USER_PROJECTION } = require('../utils/userProjection');

// -------- Categorical taxonomies (one-hot) --------
// All taxonomies come from the canonical `src/domain/taxonomies.js` module.
// Local aliases preserve the existing call-site names so the encoder reads
// the same as before. Some pairs (e.g. RELATIONSHIP_TYPE → RELATIONSHIP_TYPES)
// rename to match earlier in-file conventions.
const {
  GENDER: GENDERS,
  DATING_INTENTIONS,
  RELATIONSHIP_TYPE: RELATIONSHIP_TYPES,
  EXERCISE,
  CHILDREN,
  FAMILY_PLANS,
  RELIGION: RELIGIONS,
  POLITICS,
  VICE_LEVELS: VICE_VALUES,
  INTERESTS_TOP_30: TOP_INTERESTS,
  LANGUAGES_TOP_10: TOP_LANGUAGES,
} = require('../domain/taxonomies');

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
  if (pref === 'everyone') return [...GENDERS];
  // Default: opposite gender
  if (viewer.gender === 'female') return ['male'];
  if (viewer.gender === 'male') return ['female'];
  return [...GENDERS];
};

/**
 * ML-service-backed ideal match. Returns the same shape as the legacy path
 * (topMatch, score, alternates, commonalities) so the caller is unaware
 * which engine produced it. Returns null on any non-fatal failure so the
 * caller can fall back to the legacy cosine encoder.
 */
const getIdealMatchFromMl = async (userId, limit, viewer) => {
  if (!mlMatchClient.isEnabled()) return null;

  const k = Math.max(limit, 5);
  const result = await mlMatchClient.recommend(userId, k);
  if (!result || !Array.isArray(result.recommendations) || result.recommendations.length === 0) {
    return null;
  }

  // Hydrate the top + alternates from Mongo so the response carries the same
  // user projection the rest of the app expects. Doing this in one $in query
  // keeps it O(1) round-trips.
  const ids = result.recommendations
    .map((r) => r.candidate_id)
    .filter(Boolean)
    .slice(0, limit)
    .map((id) => new mongoose.Types.ObjectId(id));

  if (ids.length === 0) return null;

  const docs = await User.find({ _id: { $in: ids } }).select(USER_PROJECTION).lean();
  const byId = new Map(docs.map((d) => [d._id.toString(), d]));

  const ordered = result.recommendations
    .map((r) => byId.get(r.candidate_id))
    .filter(Boolean);

  if (ordered.length === 0) return null;

  const topRec = result.recommendations[0];
  return {
    topMatch: ordered[0],
    score: Number((topRec.score || 0).toFixed(4)),
    alternates: ordered.slice(1, limit).map((u, i) => {
      const rec = result.recommendations[i + 1];
      return {
        user: u,
        score: Number((rec?.score || 0).toFixed(4)),
      };
    }),
    commonalities: topRec.reasons && topRec.reasons.length > 0
      ? topRec.reasons
      : computeCommonalities(viewer, ordered[0]),
    source: 'ml',
  };
};

/**
 * Compute the ideal match for `userId`.
 * Returns { topMatch, score, alternates, commonalities }.
 *
 * Two engines, picked at runtime:
 *   1. ML service (Python, FAISS + SentenceTransformer) — when ML_SERVICE_URL
 *      is set. Higher quality, learns from swipe behavior.
 *   2. Legacy one-hot cosine over taxonomies (this file) — fallback when ML
 *      is disabled, unreachable, or returns no candidates.
 */
const getIdealMatch = async (userId, limit = 5) => {
  const cacheKey = `ideal:${userId}:${limit}`;
  const cached = await cacheGet(cacheKey);
  if (cached) return cached;

  const viewer = await User.findById(userId).lean();
  if (!viewer) throw new AppError('User not found', 404);

  // Try ML first. Any null/throw degrades to the legacy path below.
  try {
    const mlResult = await getIdealMatchFromMl(userId, limit, viewer);
    if (mlResult) {
      await cacheSet(cacheKey, mlResult, FEATURE_CACHE_TTL);
      return mlResult;
    }
  } catch (err) {
    logger.warn({ event: 'idealMatch.ml_failed', err: err.message }, 'ML path failed, falling back');
  }

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
