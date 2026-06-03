// TODO(Phase-3.1): migrate these cron-driven jobs onto the BullMQ worker.
// The Redis lock below currently provides single-leader semantics inside the
// api cluster; once on BullMQ we'll use a repeatable job + a single worker
// instance instead, and drop node-cron entirely from the api process.
//
// Deployment note (Zoho Catalyst AppSail): AppSail instances are ephemeral
// (recycled ~every 5 min) so an in-process node-cron tick is NOT guaranteed to
// fire at midnight/top-of-hour. The work bodies are therefore extracted into
// `runDailyBoost()` / `clearExpiredBoosts()` and exposed via authenticated
// `/internal/cron/*` endpoints (see src/routes/internal.routes.js) that
// Catalyst Cron calls on a schedule. node-cron remains wired for local dev.
const cron = require('node-cron');
const User = require('../models/User');
const logger = require('../utils/logger');
const { getRedis } = require('../config/redis');

const BATCH_SIZE = 5000;
const DAILY_LOCK_TTL = 3600; // 1h — well within the cron tick window.
const HOURLY_LOCK_TTL = 600; // 10 min — fits inside the hourly tick.

/**
 * Try to claim a single-instance lock for a cron tick.
 * Returns true if THIS worker should execute, false if another worker holds
 * the lock.  Falls back to PM2's NODE_APP_INSTANCE=0 when Redis is unavailable.
 */
const acquireLock = async (lockKey, ttlSeconds) => {
  let redis;
  try {
    redis = getRedis();
  } catch (_) {
    redis = null;
  }

  if (redis && redis.status === 'ready') {
    try {
      const result = await redis.set(
        lockKey,
        String(process.pid),
        'NX',
        'EX',
        ttlSeconds,
      );
      return result === 'OK';
    } catch (err) {
      logger.warn({ err: err.message, lockKey }, 'Cron lock acquire failed; falling back to instance check');
    }
  }

  // Fallback: only run on PM2 instance 0 (process.env.NODE_APP_INSTANCE is
  // set by PM2 cluster mode).  When unset (single-process dev), run.
  const inst = process.env.NODE_APP_INSTANCE;
  return inst === undefined || inst === '0';
};

/**
 * Increment `daysWithoutMatch` for all active, profile-complete male users.
 * Batched in BATCH_SIZE chunks to bound memory and lock time.
 * Idempotent-per-day is the CALLER's responsibility (run it once daily).
 *
 * @returns {Promise<{ totalModified: number }>}
 */
const runDailyBoost = async () => {
  let totalModified = 0;
  let hasMore = true;
  let lastId = null;

  while (hasMore) {
    const query = {
      gender: 'male',
      isActive: true,
      isProfileComplete: true,
    };

    if (lastId) {
      query._id = { $gt: lastId };
    }

    const users = await User.find(query)
      .select('_id')
      .sort({ _id: 1 })
      .limit(BATCH_SIZE)
      .lean();

    if (users.length === 0) {
      hasMore = false;
      break;
    }

    const ids = users.map((u) => u._id);
    const result = await User.updateMany(
      { _id: { $in: ids } },
      { $inc: { daysWithoutMatch: 1 } },
    );

    totalModified += result.modifiedCount;
    lastId = ids[ids.length - 1];

    if (users.length < BATCH_SIZE) {
      hasMore = false;
    }
  }

  logger.info({ totalModified }, 'Daily boost job completed');
  return { totalModified };
};

/**
 * Clear paid boosts whose expiry has passed.
 *
 * @returns {Promise<{ cleared: number }>}
 */
const clearExpiredBoosts = async () => {
  const result = await User.updateMany(
    {
      boostLevel: { $ne: 'none' },
      boostExpiry: { $lt: new Date() },
    },
    { boostLevel: 'none', boostExpiry: null },
  );
  if (result.modifiedCount > 0) {
    logger.info({ count: result.modifiedCount }, 'Cleared expired boosts');
  }
  return { cleared: result.modifiedCount };
};

const initCronJobs = () => {
  // Run daily at midnight UTC — increment daysWithoutMatch for all active males (batched).
  cron.schedule('0 0 * * *', async () => {
    const gotLock = await acquireLock('lock:job:dailyBoost', DAILY_LOCK_TTL);
    if (!gotLock) {
      logger.debug('Daily boost job: lock held by another worker, skipping');
      return;
    }
    try {
      await runDailyBoost();
    } catch (err) {
      logger.error({ err: err.message }, 'Daily boost job failed');
    }
  });

  // Run hourly — clear expired paid boosts.
  cron.schedule('0 * * * *', async () => {
    const gotLock = await acquireLock('lock:job:clearExpiredBoosts', HOURLY_LOCK_TTL);
    if (!gotLock) return;

    try {
      await clearExpiredBoosts();
    } catch (err) {
      logger.error({ err: err.message }, 'Clear expired boosts job failed');
    }
  });

  logger.info('Cron jobs initialized');
};

module.exports = initCronJobs;
// Exposed for the Catalyst Cron HTTP endpoints (prod) and unit tests.
module.exports.runDailyBoost = runDailyBoost;
module.exports.clearExpiredBoosts = clearExpiredBoosts;
