const { getRedis } = require('../config/redis');
const logger = require('./logger');

/**
 * Get a value from Redis cache.
 * Returns null if key doesn't exist or Redis is unavailable.
 */
const cacheGet = async (key) => {
  try {
    const redis = getRedis();
    if (redis.status !== 'ready') return null;
    const data = await redis.get(key);
    return data ? JSON.parse(data) : null;
  } catch (err) {
    logger.debug({ err: err.message, key }, 'Cache get failed');
    return null;
  }
};

/**
 * Set a value in Redis cache with TTL.
 * @param {string} key
 * @param {*} value - Will be JSON.stringify'd
 * @param {number} ttlSeconds - Time to live in seconds (default 300 = 5 min)
 */
const cacheSet = async (key, value, ttlSeconds = 300) => {
  try {
    const redis = getRedis();
    if (redis.status !== 'ready') return;
    await redis.set(key, JSON.stringify(value), 'EX', ttlSeconds);
  } catch (err) {
    logger.debug({ err: err.message, key }, 'Cache set failed');
  }
};

/**
 * Delete a specific key or pattern from cache.
 */
const cacheDel = async (key) => {
  try {
    const redis = getRedis();
    if (redis.status !== 'ready') return;
    await redis.del(key);
  } catch (err) {
    logger.debug({ err: err.message, key }, 'Cache del failed');
  }
};

/**
 * Delete all keys matching a pattern (e.g., 'feed:*').
 * Use sparingly — SCAN is O(N).
 */
const cacheDelPattern = async (pattern) => {
  try {
    const redis = getRedis();
    if (redis.status !== 'ready') return;

    let cursor = '0';
    do {
      const [nextCursor, keys] = await redis.scan(cursor, 'MATCH', pattern, 'COUNT', 100);
      cursor = nextCursor;
      if (keys.length > 0) {
        await redis.del(...keys);
      }
    } while (cursor !== '0');
  } catch (err) {
    logger.debug({ err: err.message, pattern }, 'Cache del pattern failed');
  }
};

module.exports = {
  cacheGet, cacheSet, cacheDel, cacheDelPattern,
};
