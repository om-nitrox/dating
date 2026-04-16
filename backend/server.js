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
  // Connect to MongoDB
  await connectDB();

  // Connect to Redis (required for rate limiting, caching, socket adapter)
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

  // Initialize Socket.IO with Redis adapter
  const io = initSocket(server, redisClient);
  app.set('io', io);

  // Initialize Firebase (optional, fails gracefully)
  initFirebase();

  // Start cron jobs
  initCronJobs();

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

  // Force exit after 30 seconds (enough for 1500 connections to drain)
  setTimeout(() => {
    logger.error('Forced shutdown after timeout');
    process.exit(1);
  }, 30000);
};

process.on('SIGTERM', () => shutdown('SIGTERM'));
process.on('SIGINT', () => shutdown('SIGINT'));

// Handle uncaught errors
process.on('uncaughtException', (err) => {
  logger.error({ err }, 'Uncaught exception');
  shutdown('uncaughtException');
});

process.on('unhandledRejection', (reason) => {
  logger.error({ err: reason }, 'Unhandled rejection');
});
