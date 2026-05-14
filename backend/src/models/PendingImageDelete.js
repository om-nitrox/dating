// Phase 1.2: PendingImageDelete — work queue for Cloudinary deletes that failed.
/**
 * When a Cloudinary `destroy()` call fails (transient network error, 5xx,
 * Cloudinary outage), the user's Mongo row has already been updated to drop
 * the photo reference. The asset is now an orphan on Cloudinary's side.
 *
 * Rather than synchronously retrying in the request path (and risking
 * timeouts), we persist the orphan publicId here and let the
 * `media.reaper` BullMQ repeatable job sweep it on a cadence.
 *
 * Fields:
 *   publicId       Cloudinary public id (unique — re-queueing the same id is a no-op)
 *   attempts       Number of times the reaper has tried to delete
 *   lastError      Error message from the most recent attempt (truncated to 500 chars)
 *   nextAttemptAt  When the reaper should next try (indexed for fast scan)
 *
 * Retention strategy:
 *   After 10 failed attempts the reaper logs `media.delete.give_up` and
 *   leaves the row in place for manual cleanup. We do NOT delete on
 *   give-up — the operator may want to manually invoke the Cloudinary
 *   delete (e.g. once the upstream issue is resolved) and clear the row.
 */

const mongoose = require('mongoose');

const pendingImageDeleteSchema = new mongoose.Schema(
  {
    publicId: {
      type: String,
      required: true,
      unique: true,
      index: true,
    },
    attempts: {
      type: Number,
      default: 0,
    },
    lastError: {
      type: String,
      default: '',
      maxlength: 500,
    },
    nextAttemptAt: {
      type: Date,
      required: true,
      default: () => new Date(),
      index: true,
    },
    givenUp: {
      type: Boolean,
      default: false,
      index: true,
    },
  },
  {
    timestamps: true,
  },
);

// Compound index for the reaper's primary query: rows that are due AND not
// given-up, sorted by nextAttemptAt ASC. Mongo can satisfy this with a single
// index scan.
pendingImageDeleteSchema.index({ givenUp: 1, nextAttemptAt: 1 });

module.exports = mongoose.model('PendingImageDelete', pendingImageDeleteSchema);
