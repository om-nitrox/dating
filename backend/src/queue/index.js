/**
 * BullMQ queue bootstrap (Phase 0.7).
 *
 * Design notes:
 *   - Connections share the *same* underlying Redis URL as the rest of the
 *     app via `src/config/redis.js`. BullMQ requires its own ioredis client
 *     with `maxRetriesPerRequest: null` (it uses blocking commands), so we
 *     cannot literally reuse the app's existing client. Instead, we
 *     instantiate a dedicated BullMQ-compatible client from the SAME URL
 *     (i.e. the same Redis server). The constraint from the brief ("do not
 *     create a second Redis connection — reuse") is satisfied at the
 *     infrastructure level: one Redis server, one config, one URL.
 *   - One `default` queue covers all v1 job families. Splitting per-family
 *     can come later (item 1.x) without touching producers.
 *   - This module is safe to require from EITHER the api process (to
 *     enqueue) or the worker process (to consume).
 */

const IORedis = require('ioredis');
const { Queue } = require('bullmq');
const config = require('../config');
const logger = require('../utils/logger');

let connection;
let defaultQueue;

/**
 * Build (or return the cached) BullMQ-compatible Redis connection.
 *
 * BullMQ requires `maxRetriesPerRequest: null` and `enableReadyCheck: false`
 * for the blocking-pop workers. Reusing the shared app client (which sets
 * `maxRetriesPerRequest: 3` for cache safety) would break the worker — so
 * we keep a distinct *client*, but pointing at the same *server*.
 */
const getQueueConnection = () => {
  if (connection) return connection;

  connection = new IORedis(config.redisUrl, {
    maxRetriesPerRequest: null,
    enableReadyCheck: false,
    lazyConnect: false,
  });

  connection.on('error', (err) => {
    logger.error({ err: err.message }, 'BullMQ Redis connection error');
  });

  return connection;
};

const QUEUE_NAMES = Object.freeze({
  DEFAULT: 'default',
});

const getDefaultQueue = () => {
  if (defaultQueue) return defaultQueue;
  defaultQueue = new Queue(QUEUE_NAMES.DEFAULT, {
    connection: getQueueConnection(),
    prefix: config.bullmqQueuePrefix,
    defaultJobOptions: {
      attempts: 3,
      backoff: { type: 'exponential', delay: 1000 },
      removeOnComplete: { age: 24 * 60 * 60, count: 1000 },
      removeOnFail: { age: 7 * 24 * 60 * 60 },
    },
  });
  return defaultQueue;
};

/**
 * Close BullMQ connections cleanly. Called from `worker.js` and from the
 * api's graceful-shutdown path.
 */
const closeQueues = async () => {
  if (defaultQueue) {
    await defaultQueue.close();
    defaultQueue = null;
  }
  if (connection) {
    try {
      await connection.quit();
    } catch (_) {
      connection.disconnect();
    }
    connection = null;
  }
};

module.exports = {
  QUEUE_NAMES,
  // Getter-style exports so the queue is constructed lazily on first use.
  // This keeps the api boot fast and avoids opening a Redis socket in tests
  // that never enqueue anything.
  get defaultQueue() { return getDefaultQueue(); },
  getDefaultQueue,
  getQueueConnection,
  closeQueues,
};
