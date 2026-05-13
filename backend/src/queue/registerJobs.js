/**
 * Central registry of BullMQ job handlers (Phase 0.7).
 *
 * Each entry maps a BullMQ job `name` to a handler function. The worker
 * entrypoint (`worker.js`) reads from this map to dispatch incoming jobs.
 *
 * To add a new job:
 *   1. Create `src/queue/jobs/<name>.job.js` exporting `{ NAME, handler }`.
 *   2. Require it here and append to `JOB_HANDLERS`.
 *   3. Enqueue from any api code via:
 *        const { defaultQueue } = require('./queue');
 *        await defaultQueue.add('<name>', { ...payload });
 */

const sampleJob = require('./jobs/sample.job');

const JOB_HANDLERS = Object.freeze({
  [sampleJob.NAME]: sampleJob.handler,
});

/**
 * Build a single dispatcher function the BullMQ Worker will invoke for
 * every job. Looks up the handler by job.name and falls through with a
 * clear error if the job is unknown (so a stale enqueue from an old
 * deploy doesn't silently no-op).
 */
const buildProcessor = () => async (job) => {
  const handler = JOB_HANDLERS[job.name];
  if (!handler) {
    throw new Error(`No handler registered for job name: ${job.name}`);
  }
  return handler(job);
};

module.exports = { JOB_HANDLERS, buildProcessor };
