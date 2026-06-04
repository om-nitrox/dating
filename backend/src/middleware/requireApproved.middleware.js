const User = require('../models/User');
const AppError = require('../utils/AppError');

// Account-approval gate for girls.
//
// Female accounts must be manually approved by an admin before they can use
// the core app (feed / ideal-match). Approval reuses the existing selfie
// review pipeline: `selfieReviewStatus === 'approved'` is the gate.
//
// Boys are never gated — they pass straight through regardless of selfie
// state (their selfie only drives the optional "verified" badge).
//
// We always read the authoritative state from the DB (the JWT has no
// approval claim). A tiny in-process TTL cache mirrors gender.middleware so
// we don't hit Mongo on every request.
const CACHE_TTL_MS = 15 * 1000;
const cache = new Map();

const getCached = (userId) => {
  const entry = cache.get(userId);
  if (!entry) return undefined;
  if (entry.exp < Date.now()) {
    cache.delete(userId);
    return undefined;
  }
  return entry.value;
};

const setCached = (userId, value) => {
  cache.set(userId, { value, exp: Date.now() + CACHE_TTL_MS });
  if (cache.size > 10000) {
    const firstKey = cache.keys().next().value;
    cache.delete(firstKey);
  }
};

const invalidate = (userId) => {
  if (userId) cache.delete(String(userId));
};

const requireApproved = async (req, res, next) => {
  try {
    let state = getCached(req.user.id);
    if (state === undefined) {
      const u = await User.findById(req.user.id, {
        gender: 1,
        selfieReviewStatus: 1,
      }).lean();
      state = u
        ? { gender: u.gender || null, status: u.selfieReviewStatus || 'none' }
        : { gender: null, status: 'none' };
      setCached(req.user.id, state);
    }

    // Only girls are gated.
    if (state.gender !== 'female') return next();

    if (state.status !== 'approved') {
      return next(
        new AppError(
          'Your profile is under verification. You can access the app once an admin approves it.',
          403,
          'PROFILE_PENDING_APPROVAL',
        ),
      );
    }

    return next();
  } catch (err) {
    return next(err);
  }
};

requireApproved.invalidate = invalidate;
// eslint-disable-next-line no-underscore-dangle
requireApproved._cache = cache;

module.exports = requireApproved;
