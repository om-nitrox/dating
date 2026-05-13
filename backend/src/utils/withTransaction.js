const mongoose = require('mongoose');
const config = require('../config');
const logger = require('./logger');

/**
 * Run `work(session)` inside a Mongo transaction when transactions are
 * available, falling back to sequential writes (no session) otherwise.
 *
 * `work` MUST be tolerant of session=null (e.g., pass `{ session }` options
 * conditionally to write/update calls). The callback may be invoked more than
 * once if the transaction is retried by `withTransaction`.
 *
 * Standalone MongoDB throws on `startSession().withTransaction()`. In that
 * case (and when MONGO_TRANSACTIONS_ENABLED=false) we log a warning once
 * per process and execute the work without a session.
 */
let warnedFallback = false;

const runWithTransaction = async (work) => {
  if (!config.mongoTransactionsEnabled) {
    if (!warnedFallback) {
      logger.warn('MONGO_TRANSACTIONS_ENABLED=false — running multi-doc cascades sequentially');
      warnedFallback = true;
    }
    return work(null);
  }

  let session;
  try {
    session = await mongoose.startSession();
  } catch (err) {
    if (!warnedFallback) {
      logger.warn({ err: err.message }, 'Could not start Mongo session — falling back to sequential writes');
      warnedFallback = true;
    }
    return work(null);
  }

  try {
    let result;
    await session.withTransaction(async () => {
      result = await work(session);
    });
    return result;
  } catch (err) {
    // Standalone mongo / no-replicaset: silently fall back so dev keeps working.
    const message = err && err.message ? err.message : '';
    const isStandalone = err
      && (err.code === 20
        || err.codeName === 'IllegalOperation'
        || /Transaction numbers are only allowed/i.test(message)
        || /replica set|Transactions are not supported/i.test(message));
    if (isStandalone) {
      if (!warnedFallback) {
        logger.warn({ err: message }, 'Mongo does not support transactions here — falling back to sequential writes');
        warnedFallback = true;
      }
      return work(null);
    }
    throw err;
  } finally {
    if (session) await session.endSession();
  }
};

module.exports = runWithTransaction;
