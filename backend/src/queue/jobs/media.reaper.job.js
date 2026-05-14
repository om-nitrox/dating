// Phase 1.2: media reaper — sweep PendingImageDelete rows and retry the Cloudinary delete.
/**
 * Repeatable BullMQ job invoked on a 5-minute cadence (configurable via
 * `MEDIA_REAPER_INTERVAL_MS`).
 *
 * Behaviour:
 *   1. Find up to N PendingImageDelete rows with `nextAttemptAt <= now` and
 *      `givenUp = false`, ordered by `nextAttemptAt` ASC.
 *   2. For each row, try Cloudinary `destroy(publicId)`.
 *      - Success: delete the row, bump `media_delete_total{status="success"}`.
 *      - Failure: increment `attempts`, set `lastError`, schedule
 *        `nextAttemptAt = now + min(60 * 2^attempts, 3600)s`. If attempts
 *        reaches 10 we flip `givenUp = true` and emit `media.delete.give_up`.
 *
 * Why a single batch per tick:
 *   Limits the worst-case work per tick so a long Cloudinary outage
 *   doesn't pile a thousand sequential retries into one job execution.
 *   Each tick processes up to BATCH_SIZE rows; if there are more, the
 *   next tick picks them up.
 *
 * Concurrency:
 *   The reaper is single-instance — we lean on BullMQ's "repeatable job"
 *   semantics. If we scale the worker fleet, BullMQ uses a Redis lock per
 *   repeat key, so only one instance actually claims the tick.
 */

const PendingImageDelete = require('../../models/PendingImageDelete');
const { deleteImage } = require('../../services/upload.service');
const { mediaDeleteTotal } = require('../../observability/metrics');
const logger = require('../../utils/logger');

const NAME = 'media.reaper';

const BATCH_SIZE = 25;
const MAX_ATTEMPTS = 10;
const BASE_BACKOFF_SEC = 60;
const CAP_BACKOFF_SEC = 3600;

const nextAttemptAt = (attempts) => {
  const delaySec = Math.min(BASE_BACKOFF_SEC * (2 ** attempts), CAP_BACKOFF_SEC);
  return new Date(Date.now() + delaySec * 1000);
};

const handler = async (_job) => {
  const now = new Date();
  const rows = await PendingImageDelete.find({
    nextAttemptAt: { $lte: now },
    givenUp: { $ne: true },
  })
    .sort({ nextAttemptAt: 1 })
    .limit(BATCH_SIZE);

  if (rows.length === 0) {
    return { processed: 0 };
  }

  let success = 0;
  let failed = 0;
  let gaveUp = 0;

  for (const row of rows) {
    try {
      // eslint-disable-next-line no-await-in-loop
      await deleteImage(row.publicId);
      // eslint-disable-next-line no-await-in-loop
      await PendingImageDelete.deleteOne({ _id: row._id });
      mediaDeleteTotal.labels({ status: 'success' }).inc();
      success += 1;
      logger.info(
        { event: 'media.delete.success', publicId: row.publicId, attempts: row.attempts + 1 },
        'cloudinary delete succeeded via reaper',
      );
    } catch (err) {
      const nextAttempts = row.attempts + 1;
      const reachedCap = nextAttempts >= MAX_ATTEMPTS;
      const update = {
        $set: {
          attempts: nextAttempts,
          lastError: String(err.message || err).slice(0, 500),
          nextAttemptAt: reachedCap ? row.nextAttemptAt : nextAttemptAt(nextAttempts),
        },
      };
      if (reachedCap) {
        update.$set.givenUp = true;
      }
      // eslint-disable-next-line no-await-in-loop
      await PendingImageDelete.updateOne({ _id: row._id }, update);
      if (reachedCap) {
        mediaDeleteTotal.labels({ status: 'gave_up' }).inc();
        gaveUp += 1;
        logger.error(
          {
            event: 'media.delete.give_up',
            publicId: row.publicId,
            attempts: nextAttempts,
            err: err.message,
          },
          'cloudinary delete gave up after max attempts',
        );
      } else {
        mediaDeleteTotal.labels({ status: 'failed' }).inc();
        failed += 1;
        logger.warn(
          {
            event: 'media.delete.retry',
            publicId: row.publicId,
            attempts: nextAttempts,
            err: err.message,
          },
          'cloudinary delete failed; will retry',
        );
      }
    }
  }

  return {
    processed: rows.length, success, failed, gaveUp,
  };
};

module.exports = {
  NAME, handler, BATCH_SIZE, MAX_ATTEMPTS,
};
