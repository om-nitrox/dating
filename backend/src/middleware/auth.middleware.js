const { verifyAccessToken } = require('../utils/token');
const { getRedis } = require('../config/redis');
const User = require('../models/User');
const AppError = require('../utils/AppError');

// Tiny in-process TTL cache to absorb the per-request DB ban-check lookup.
// Map<userId, { banned: boolean, exp: number /* epoch ms */ }>
const BAN_CACHE_TTL_MS = 30 * 1000;
const banCache = new Map();

const getCachedBan = (userId) => {
  const entry = banCache.get(userId);
  if (!entry) return undefined;
  if (entry.exp < Date.now()) {
    banCache.delete(userId);
    return undefined;
  }
  return entry.banned;
};

const setCachedBan = (userId, banned) => {
  banCache.set(userId, { banned, exp: Date.now() + BAN_CACHE_TTL_MS });
  // Bound cache size — drop oldest entries when over 10k.
  if (banCache.size > 10000) {
    const firstKey = banCache.keys().next().value;
    banCache.delete(firstKey);
  }
};

const auth = async (req, res, next) => {
  const header = req.headers.authorization;

  if (!header || !header.startsWith('Bearer ')) {
    return next(new AppError('No token provided', 401));
  }

  const token = header.split(' ')[1];

  let decoded;
  try {
    decoded = verifyAccessToken(token);
  } catch (err) {
    if (err.name === 'TokenExpiredError') {
      return next(new AppError('Token expired', 401));
    }
    return next(new AppError('Invalid token', 401));
  }

  let redisOk = true;
  try {
    const redis = getRedis();

    // Check JWT blacklist (tokens invalidated on logout)
    if (decoded.jti) {
      const blacklisted = await redis.get(`blacklist:${decoded.jti}`);
      if (blacklisted) {
        return next(new AppError('Token has been revoked', 401));
      }
    }

    // Check banned-users set (immediate revocation after admin ban)
    const isBanned = await redis.get(`banned:${decoded.id}`);
    if (isBanned) {
      return next(new AppError('Your account has been suspended', 403));
    }
  } catch (_) {
    redisOk = false;
    // Redis unavailable — fail open in dev, fail closed in prod
    if (process.env.NODE_ENV === 'production') {
      return next(new AppError('Authentication service unavailable', 503));
    }
  }

  // DB ban check (always, with a short in-process cache).  This protects us
  // when (a) the Redis flag has expired/cleared but the DB still has banned=true
  // and (b) Redis is unavailable in non-prod.
  try {
    const cached = getCachedBan(decoded.id);
    let banned = cached;
    if (banned === undefined) {
      const user = await User.findById(decoded.id, { banned: 1 }).lean();
      banned = !!(user && user.banned);
      setCachedBan(decoded.id, banned);
    }
    if (banned) {
      return next(new AppError('Your account has been suspended', 403));
    }
  } catch (err) {
    // If the DB lookup itself fails, behave like Redis: closed in prod, open in dev.
    if (process.env.NODE_ENV === 'production' && !redisOk) {
      return next(new AppError('Authentication service unavailable', 503));
    }
  }

  req.user = {
    id: decoded.id,
    gender: decoded.gender,
    jti: decoded.jti,
    tokenExp: decoded.exp,
  };

  req.token = token;

  next();
};

module.exports = auth;
// eslint-disable-next-line no-underscore-dangle
module.exports._banCache = banCache; // exported for tests
