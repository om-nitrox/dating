const User = require('../models/User');
const AppError = require('../utils/AppError');

// JWTs may have a STALE gender claim (e.g., user signed up before completing
// onboarding, then set gender). Always read gender from the DB (with a small
// in-process TTL cache to avoid round trips) instead of trusting the token.
const GENDER_CACHE_TTL_MS = 30 * 1000;
const genderCache = new Map();

const getCachedGender = (userId) => {
  const entry = genderCache.get(userId);
  if (!entry) return undefined;
  if (entry.exp < Date.now()) {
    genderCache.delete(userId);
    return undefined;
  }
  return entry.gender; // may be null
};

const setCachedGender = (userId, gender) => {
  genderCache.set(userId, { gender, exp: Date.now() + GENDER_CACHE_TTL_MS });
  if (genderCache.size > 10000) {
    const firstKey = genderCache.keys().next().value;
    genderCache.delete(firstKey);
  }
};

const invalidateGenderCache = (userId) => {
  if (userId) genderCache.delete(String(userId));
};

const requireGender = (gender) => async (req, res, next) => {
  try {
    let dbGender = getCachedGender(req.user.id);
    if (dbGender === undefined) {
      const u = await User.findById(req.user.id, { gender: 1 }).lean();
      dbGender = u ? u.gender || null : null;
      setCachedGender(req.user.id, dbGender);
    }

    // Keep req.user.gender in sync with the authoritative value so downstream
    // code that reads req.user.gender doesn't accidentally use the stale JWT.
    req.user.gender = dbGender;

    if (!dbGender) {
      return next(
        new AppError(
          'Complete onboarding to access this feature',
          403,
          'GENDER_REQUIRED',
        ),
      );
    }

    if (dbGender !== gender) {
      return next(
        new AppError(
          `This action is only available for ${gender} users`,
          403,
        ),
      );
    }
    return next();
  } catch (err) {
    return next(err);
  }
};

requireGender.invalidate = invalidateGenderCache;
// eslint-disable-next-line no-underscore-dangle
requireGender._genderCache = genderCache;

module.exports = requireGender;
