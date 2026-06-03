const http = require('http');
const app = require('./src/app');
const config = require('./src/config');
const connectDB = require('./src/config/db');
const { initFirebase } = require('./src/config/firebase');
const { connectRedis } = require('./src/config/redis');
const initSocket = require('./src/socket');
const initCronJobs = require('./src/jobs/dailyBoost.job');
const logger = require('./src/utils/logger');

const server = http.createServer(app);

const start = async () => {
  // Connect to Redis (required for rate limiting, caching, socket adapter).
  // We attempt Redis first because Socket.IO benefits from the adapter being
  // available when it boots, and so we can attach `io` to the app BEFORE
  // MongoDB is up — handlers that depend on `req.app.get('io')` no longer
  // race with the very first inbound request.
  let redisClient = null;
  try {
    redisClient = connectRedis();
    await redisClient.connect();
    logger.info('Redis connection established');
  } catch (err) {
    if (config.nodeEnv === 'production') {
      logger.error({ err: err.message }, 'Redis is required in production — aborting startup');
      process.exit(1);
    }
    logger.warn({ err: err.message }, 'Redis not available — running without cache/socket-adapter (dev only)');
  }

  // Initialize Socket.IO BEFORE the DB connect so it is observable through
  // app.get('io') for any handler that runs while DB is still connecting
  // (fix 21).
  const io = initSocket(server, redisClient);
  app.set('io', io);

  // Connect to MongoDB
  await connectDB();

  // Initialize Firebase (optional, fails gracefully)
  initFirebase();

  // Start in-process cron jobs (single-leader via Redis lock — see
  // dailyBoost.job). On ephemeral hosts like Zoho Catalyst AppSail these
  // ticks aren't reliable, so in production the work is driven externally by
  // Catalyst Cron hitting /internal/cron/* instead. Opt back in with
  // ENABLE_INPROCESS_CRON=true (e.g. a long-lived self-hosted/PM2 deploy).
  const inProcessCron = config.nodeEnv !== 'production'
    || process.env.ENABLE_INPROCESS_CRON === 'true';
  if (inProcessCron) {
    initCronJobs();
  } else {
    logger.info('In-process cron disabled in production; using Catalyst Cron → /internal/cron/*');
  }

  server.listen(config.port, () => {
    logger.info({
      port: config.port,
      env: config.nodeEnv,
      pid: process.pid,
    }, 'Server started');
  });
};

start().catch((err) => {
  logger.error({ err }, 'Failed to start server');
  process.exit(1);
});

// Graceful shutdown
const shutdown = async (signal) => {
  logger.info({ signal }, 'Shutdown signal received');

  // Stop accepting new connections
  server.close(async () => {
    logger.info('HTTP server closed');

    try {
      // Close MongoDB
      const mongoose = require('mongoose');
      await mongoose.connection.close();
      logger.info('MongoDB connection closed');
    } catch (err) {
      logger.error({ err: err.message }, 'Error closing MongoDB');
    }

    try {
      // Close Redis
      const { getRedis } = require('./src/config/redis');
      const redis = getRedis();
      if (redis && redis.status === 'ready') {
        await redis.quit();
        logger.info('Redis connection closed');
      }
    } catch {
      // Ignore redis close errors
    }

    process.exit(0);
  });

  // Force exit after 30 seconds (enough for 1500 connections to drain).
  // `.unref()` so the timer itself doesn't keep the event loop alive when
  // graceful shutdown completes early (fix 31).
  setTimeout(() => {
    logger.error('Forced shutdown after timeout');
    process.exit(1);
  }, 30000).unref();
};

process.on('SIGTERM', () => shutdown('SIGTERM'));
process.on('SIGINT', () => shutdown('SIGINT'));

// Handle uncaught errors
process.on('uncaughtException', (err) => {
  logger.error({ err }, 'Uncaught exception');
  shutdown('uncaughtException');
});

// Unhandled rejections: log everywhere. In production, fail fast so the
// process manager (PM2/k8s) restarts on a clean slate (fix 31).
process.on('unhandledRejection', (reason) => {
  logger.error({ err: reason }, 'Unhandled rejection');
  if (config.nodeEnv === 'production') {
    shutdown('unhandledRejection');
  }
});
