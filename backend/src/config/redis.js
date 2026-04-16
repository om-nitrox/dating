const Redis = require('ioredis');
const config = require('./index');
const logger = require('../utils/logger');

let redis = null;

const connectRedis = () => {
  if (redis) return redis;

  redis = new Redis(config.redisUrl, {
    maxRetriesPerRequest: 3,
    retryStrategy(times) {
      if (times > 5) {
        logger.warn('Redis max retries reached, stopping reconnection');
        return null; // Stop retrying
      }
      return Math.min(times * 500, 5000);
    },
    lazyConnect: true,
  });

  redis.on('connect', () => {
    logger.info('Redis connected');
  });

  redis.on('error', (err) => {
    logger.error({ err: err.message }, 'Redis connection error');
  });

  redis.on('close', () => {
    logger.warn('Redis connection closed');
  });

  return redis;
};

const getRedis = () => {
  if (!redis) {
    return connectRedis();
  }
  return redis;
};

module.exports = { connectRedis, getRedis };
