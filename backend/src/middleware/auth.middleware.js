const { verifyAccessToken } = require('../utils/token');
const { getRedis } = require('../config/redis');
const AppError = require('../utils/AppError');

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
    // Redis unavailable — fail open in dev, fail closed in prod
    if (process.env.NODE_ENV === 'production') {
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
