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
 * Build the durable exclusion set (self + interacted + blocked + matched).
 */
const buildExcludeIds = async (userId) => {
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

  return [...excludeSet].map((id) => new mongoose.Types.ObjectId(id));
};

/**
 * Build the Mongo candidate filter from the viewer's saved discovery
 * preferences. Age always applies (it has schema defaults); height + intent
 * only constrain when the viewer explicitly set them. This is the SAME filter
 * the swipe feed uses, so a girl's Ideal Match pool matches what she browses —
 * apply a filter in discovery and it carries into the ML reveal.
 */
const buildCandidateFilter = (viewer, targetGenders, excludeIds) => {
  const prefs = viewer.preferences || {};
  const ageMin = prefs.ageMin ?? 18;
  const ageMax = prefs.ageMax ?? 99;

  const filter = {
    _id: { $nin: excludeIds },
    gender: { $in: targetGenders },
    isActive: true,
    isProfileComplete: true,
    age: { $gte: ageMin, $lte: ageMax },
  };

  if (prefs.heightMin != null || prefs.heightMax != null) {
    filter.height = {};
    if (prefs.heightMin != null) filter.height.$gte = prefs.heightMin;
    if (prefs.heightMax != null) filter.height.$lte = prefs.heightMax;
  }
  if (prefs.intent) filter.datingIntentions = prefs.intent;

  return filter;
};

/**
 * Run the candidate query (geo-aware). `idsOnly` returns lightweight {_id}
 * docs for building the ML allow-list; otherwise full projected docs for the
 * legacy cosine fallback. Hard-capped at 500 for v1 scale.
 */
const runCandidateQuery = async (viewer, candidateFilter, idsOnly) => {
  const maxDistanceKm = viewer.preferences?.maxDistance ?? 200;
  const coords = viewer.location?.coordinates;
  const hasLocation = Array.isArray(coords)
    && coords.length === 2
    && !(coords[0] === 0 && coords[1] === 0);

  if (hasLocation) {
    return User.aggregate([
      {
        $geoNear: {
          near: { type: 'Point', coordinates: coords },
          distanceField: 'distance',
          maxDistance: maxDistanceKm * 1000,
          spherical: true,
          query: candidateFilter,
        },
      },
      { $project: idsOnly ? { _id: 1 } : { ...USER_PROJECTION, distance: 1 } },
      { $limit: 500 },
    ]);
  }

  const q = User.find(candidateFilter).limit(500);
  return idsOnly
    ? q.select('_id').lean()
    : q.select(USER_PROJECTION).lean();
};

/**
 * ML-service-backed ideal match. `allowedIds` is the hard pre-filtered
 * candidate pool (age/height/intent already applied in Mongo); the ML service
 * ranks ONLY within it, so discovery filters constrain the result while the
 * embedding model still does the compatibility ranking. Returns the same
 * shape as the legacy path so the caller is engine-agnostic. Returns null on
 * any non-fatal failure so the caller can fall back to the cosine encoder.
 */
const getIdealMatchFromMl = async (userId, limit, viewer, allowedIds) => {
  if (!mlMatchClient.isEnabled()) return null;

  const k = Math.max(limit, 5);
  const result = await mlMatchClient.recommend(userId, k, allowedIds);
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

  const targetGenders = resolveTargetGenders(viewer);
  const excludeIds = await buildExcludeIds(userId);
  // Same filter the swipe feed uses (gender + active + complete + age, plus
  // height/intent when the viewer set them). This is what carries discovery
  // filters into the Ideal Match.
  const candidateFilter = buildCandidateFilter(viewer, targetGenders, excludeIds);

  // Try ML first, constrained to the hard-filtered candidate pool. A genuine
  // "no candidates" 404 propagates; any other null/throw degrades to the
  // legacy cosine path below.
  try {
    if (mlMatchClient.isEnabled()) {
      const idDocs = await runCandidateQuery(viewer, candidateFilter, true);
      const allowedIds = idDocs.map((d) => d._id.toString());
      if (allowedIds.length === 0) {
        throw new AppError('No ideal match yet — try widening your filters', 404);
      }
      const mlResult = await getIdealMatchFromMl(userId, limit, viewer, allowedIds);
      if (mlResult) {
        await cacheSet(cacheKey, mlResult, FEATURE_CACHE_TTL);
        return mlResult;
      }
    }
  } catch (err) {
    if (err instanceof AppError && err.statusCode === 404) throw err;
    logger.warn({ event: 'idealMatch.ml_failed', err: err.message }, 'ML path failed, falling back');
  }

  // Legacy cosine fallback — over the SAME filtered candidate pool, so the
  // result respects the discovery filters even when ML is unavailable.
  const candidates = await runCandidateQuery(viewer, candidateFilter, false);

  if (candidates.length === 0) {
    throw new AppError('No ideal match yet — try widening your filters', 404);
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

// ---------------------------------------------------------------------------
// Ideal Match feature (girls-only): swipe + profile-completion gates plus a
// rolling 7-day usage cap. The eligibility is enforced server-side from
// durable Mongo data (Like docs + User.idealMatchUses) so an ML-service
// restart can never wrongly lock/unlock a user.
// ---------------------------------------------------------------------------
const IDEAL_MIN_SWIPES = 10;
const IDEAL_WEEKLY_CAP = 2;
const IDEAL_COMPLETION_THRESHOLD = 0.8;
const WEEK_MS = 7 * 24 * 60 * 60 * 1000;

/** Fraction (0..1) of key profile fields filled — must match the client. */
const computeCompletion = (u) => {
  const checks = [
    !!u.name,
    u.age !== undefined && u.age !== null,
    !!u.gender,
    (u.photos ? u.photos.length : 0) >= 2,
    !!u.bio,
    (u.prompts ? u.prompts.length : 0) > 0,
    (u.interests ? u.interests.length : 0) > 0,
    !!u.education,
    !!(u.hometown || (u.location && u.location.city)),
    !!u.datingIntentions,
    u.height !== undefined && u.height !== null,
  ];
  return checks.filter(Boolean).length / checks.length;
};

/**
 * Eligibility snapshot for the Ideal Match button. Pure read — never consumes
 * a use. `userDoc` may be passed to avoid a re-fetch (e.g., from reveal).
 */
const getIdealMatchStatus = async (userId, userDoc = null) => {
  const user = userDoc || (await User.findById(userId).lean());
  if (!user) throw new AppError('User not found', 404);

  const swipeCount = await Like.countDocuments({ fromUser: userId });
  const completion = computeCompletion(user);

  const now = Date.now();
  const cutoff = now - WEEK_MS;
  const recent = (user.idealMatchUses || [])
    .map((d) => new Date(d).getTime())
    .filter((t) => t > cutoff);
  const usesThisWeek = recent.length;

  const swipesOk = swipeCount >= IDEAL_MIN_SWIPES;
  const profileOk = completion >= IDEAL_COMPLETION_THRESHOLD;
  const capOk = usesThisWeek < IDEAL_WEEKLY_CAP;

  let nextResetAt = null;
  if (!capOk && recent.length > 0) {
    nextResetAt = new Date(Math.min(...recent) + WEEK_MS).toISOString();
  }

  return {
    eligible: swipesOk && profileOk && capOk,
    swipeCount,
    minSwipes: IDEAL_MIN_SWIPES,
    completion: Number(completion.toFixed(2)),
    completionThreshold: IDEAL_COMPLETION_THRESHOLD,
    usesThisWeek,
    weeklyCap: IDEAL_WEEKLY_CAP,
    nextResetAt,
    swipesOk,
    profileOk,
    capOk,
  };
};

/**
 * Run the ML model and reveal the single ideal match, consuming one weekly
 * use. The use is recorded ONLY after a match is successfully produced, so a
 * "no candidates" result never wastes one of the two weekly tries.
 */
const revealIdealMatch = async (userId) => {
  const user = await User.findById(userId);
  if (!user) throw new AppError('User not found', 404);

  const status = await getIdealMatchStatus(userId, user.toObject());
  if (!status.swipesOk) {
    throw new AppError(
      `Swipe a few more profiles to unlock — ${status.minSwipes - status.swipeCount} to go.`,
      403,
      'IDEAL_MATCH_LOCKED',
    );
  }
  if (!status.profileOk) {
    throw new AppError(
      `Complete your profile to ${Math.round(status.completionThreshold * 100)}% first (you're at ${Math.round(status.completion * 100)}%).`,
      403,
      'IDEAL_MATCH_LOCKED',
    );
  }
  if (!status.capOk) {
    throw new AppError(
      "You've already found your ideal matches this week. Check back soon.",
      429,
      'IDEAL_MATCH_CAP',
    );
  }

  // Fresh compute each reveal (bust the 24h cache) so a second reveal in the
  // same week can surface a different person. Throws 404 if no candidates —
  // in which case the use below is NOT recorded.
  await invalidateIdealMatch(userId.toString());
  const result = await getIdealMatch(userId, 1);

  const cutoff = Date.now() - WEEK_MS;
  const kept = (user.idealMatchUses || []).filter(
    (d) => new Date(d).getTime() > cutoff,
  );
  kept.push(new Date());
  user.idealMatchUses = kept;
  await user.save();

  return { ...result, usesThisWeek: kept.length, weeklyCap: IDEAL_WEEKLY_CAP };
};

module.exports = {
  getIdealMatch,
  invalidateIdealMatch,
  getIdealMatchStatus,
  revealIdealMatch,
};
