const { rateLimit, ipKeyGenerator } = require('express-rate-limit');
const { RedisStore } = require('rate-limit-redis');
const { getRedis } = require('../config/redis');
const config = require('../config');

/**
 * Create a Redis-backed rate limiter store.
 * Falls back to in-memory if Redis is not ready (dev only — production must have Redis).
 */
const createStore = (prefix) => {
  try {
    const redis = getRedis();
    if (redis && redis.status === 'ready') {
      return new RedisStore({
        sendCommand: (...args) => redis.call(...args),
        prefix: `rl:${prefix}:`,
      });
    }
  } catch (_) {}

  // In-memory fallback (only safe for single-instance dev)
  return undefined;
};

const authLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  max: 10,
  standardHeaders: true,
  legacyHeaders: false,
  store: createStore('auth'),
  message: {
    error: { code: 'RATE_LIMIT', message: 'Too many auth attempts, try again later' },
  },
  keyGenerator: (req) => ipKeyGenerator(req),
});

// Email key normalizer for OTP limiters. Lowercases the email and falls back
// to the request IP when the body is missing/invalid (defense-in-depth: even
// if a request slips past validation, IP-based limiting still applies).
const otpKey = (prefix) => (req) => {
  const raw = req.body && typeof req.body.email === 'string' ? req.body.email : '';
  const email = raw.trim().toLowerCase();
  const looksLikeEmail = /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email);
  if (looksLikeEmail) return `${prefix}:${email}`;
  return `${prefix}:${ipKeyGenerator(req)}`;
};

const otpVerifyLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  max: 5,
  standardHeaders: true,
  legacyHeaders: false,
  store: createStore('otp-verify'),
  message: {
    error: { code: 'RATE_LIMIT', message: 'Too many OTP attempts, try again later' },
  },
  keyGenerator: otpKey('otp'),
});

const otpSendLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  max: 3,
  standardHeaders: true,
  legacyHeaders: false,
  store: createStore('otp-send'),
  message: {
    error: { code: 'RATE_LIMIT', message: 'Too many OTP requests, try again later' },
  },
  keyGenerator: otpKey('otp-send'),
});

const likeLimiter = rateLimit({
  windowMs: config.likeRateLimitWindowMs,
  max: config.likeRateLimitMax,
  standardHeaders: true,
  legacyHeaders: false,
  store: createStore('like'),
  message: {
    error: { code: 'RATE_LIMIT', message: 'Like limit reached, try again later' },
  },
  keyGenerator: (req) => req.user?.id || ipKeyGenerator(req),
});

const messageLimiter = rateLimit({
  windowMs: 60 * 60 * 1000,
  max: 200,
  standardHeaders: true,
  legacyHeaders: false,
  store: createStore('message'),
  message: {
    error: { code: 'RATE_LIMIT', message: 'Message limit reached, try again later' },
  },
  keyGenerator: (req) => req.user?.id || ipKeyGenerator(req),
});

const globalLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  max: 1000,
  standardHeaders: true,
  legacyHeaders: false,
  store: createStore('global'),
  message: {
    error: { code: 'RATE_LIMIT', message: 'Too many requests, try again later' },
  },
});

/** Rate limiter for match/safety mutation endpoints */
const mutationLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  max: 30,
  standardHeaders: true,
  legacyHeaders: false,
  store: createStore('mutation'),
  message: {
    error: { code: 'RATE_LIMIT', message: 'Too many requests, try again later' },
  },
  keyGenerator: (req) => req.user?.id || ipKeyGenerator(req),
});

/** Rate limiter for swipe undo (strict — 5 per hour) */
const undoLimiter = rateLimit({
  windowMs: 60 * 60 * 1000,
  max: 5,
  standardHeaders: true,
  legacyHeaders: false,
  store: createStore('undo'),
  message: {
    error: { code: 'RATE_LIMIT', message: 'Undo limit reached, try again later' },
  },
  keyGenerator: (req) => req.user?.id || ipKeyGenerator(req),
});

module.exports = {
  authLimiter,
  otpVerifyLimiter,
  otpSendLimiter,
  likeLimiter,
  messageLimiter,
  globalLimiter,
  mutationLimiter,
  undoLimiter,
};
