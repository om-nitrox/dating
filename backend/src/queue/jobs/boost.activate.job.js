// Phase 1.1: BullMQ job — activate a boost out-of-band from the Stripe webhook.
/**
 * `boost.activate` job handler.
 *
 * Why split this out of the webhook handler:
 *   - Stripe will retry a non-2xx webhook for up to 3 days. A slow DB write
 *     (or a Mongo failover blip) could push the synchronous activation past
 *     the 30s socket timeout and produce duplicate retries.
 *   - The webhook handler now does: verify signature -> upsert WebhookEvent
 *     -> enqueue this job -> 200. Target latency <50ms.
 *   - This job idempotently activates the boost. The WebhookEvent upsert
 *     in the controller is the dedupe gate; this job assumes its input
 *     payload was vetted.
 *
 * Payload shape:
 *   {
 *     eventId: string,        // Stripe event id (for tracing)
 *     userId: string,         // ObjectId as string
 *     tier: 'bronze'|'silver'|'gold',
 *     durationMinutes: number,
 *   }
 *
 * Failure handling:
 *   On any DB error we throw — BullMQ will retry per the default options
 *   in `src/queue/index.js` (3 attempts with exponential backoff). After
 *   the final attempt the job moves to `failed` and emits a structured log
 *   + `job_processed_total{status="failed"}` metric.
 *
 * Backpressure trade-off:
 *   The webhook always returns 200 even when the queue is slow. Stripe
 *   won't retry, so a long queue lag = a long activation lag. Acceptable
 *   at our scale (boost activations are tens-per-day at peak); when load
 *   grows past that we can split this into its own queue and add a SLO
 *   alert on queue depth.
 */

const { activateBoost } = require('../../services/boost.service');
const logger = require('../../utils/logger');

const NAME = 'boost.activate';

const handler = async (job) => {
  const {
    eventId, userId, tier, durationMinutes,
  } = job.data || {};

  if (!userId || !tier || !durationMinutes) {
    throw new Error(
      `boost.activate: missing payload fields (got: ${JSON.stringify(job.data)})`,
    );
  }

  await activateBoost(userId, tier, parseInt(durationMinutes, 10));

  logger.info(
    {
      event: 'boost.activate.job.completed',
      jobId: job.id,
      eventId,
      userId,
      tier,
      durationMinutes,
    },
    'boost activated via background job',
  );

  return { activated: true };
};

module.exports = { NAME, handler };
