// Internal cron endpoints (Zoho Catalyst AppSail deployment).
//
// AppSail instances are ephemeral, so the in-process node-cron schedule in
// src/jobs/dailyBoost.job.js is not reliable in production. Instead, Catalyst
// Cron calls these authenticated endpoints on a schedule:
//   - POST /internal/cron/daily-boost           (daily 00:00 UTC)
//   - POST /internal/cron/clear-expired-boosts  (hourly)
//
// Every call must present the shared secret in the `X-Cron-Secret` header,
// matched in constant time against CRON_SECRET.
const express = require('express');
const crypto = require('crypto');
const config = require('../config');
const logger = require('../utils/logger');
const { runDailyBoost, clearExpiredBoosts } = require('../jobs/dailyBoost.job');

const router = express.Router();

// Constant-time comparison so a wrong secret can't be timed byte-by-byte.
const secretMatches = (provided) => {
  if (!config.cronSecret || !provided) return false;
  const a = Buffer.from(String(provided));
  const b = Buffer.from(config.cronSecret);
  if (a.length !== b.length) return false;
  return crypto.timingSafeEqual(a, b);
};

// Guard: reject unless CRON_SECRET is configured AND the header matches.
router.use((req, res, next) => {
  if (!config.cronSecret) {
    logger.warn('Rejected /internal/cron call: CRON_SECRET not configured');
    return res.status(503).json({
      error: { code: 'CRON_DISABLED', message: 'Cron secret not configured' },
    });
  }
  if (!secretMatches(req.get('X-Cron-Secret'))) {
    return res.status(401).json({
      error: { code: 'UNAUTHORIZED', message: 'Invalid cron secret' },
    });
  }
  return next();
});

// POST /internal/cron/daily-boost
router.post('/daily-boost', async (req, res, next) => {
  try {
    const result = await runDailyBoost();
    return res.json({ ok: true, job: 'daily-boost', ...result });
  } catch (err) {
    return next(err);
  }
});

// POST /internal/cron/clear-expired-boosts
router.post('/clear-expired-boosts', async (req, res, next) => {
  try {
    const result = await clearExpiredBoosts();
    return res.json({ ok: true, job: 'clear-expired-boosts', ...result });
  } catch (err) {
    return next(err);
  }
});

module.exports = router;
