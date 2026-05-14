const boostService = require('../services/boost.service');
const catchAsync = require('../utils/catchAsync');
const logger = require('../utils/logger');

const getPlans = catchAsync(async (req, res) => {
  const plans = boostService.getPlans();
  res.status(200).json({ plans });
});

const purchaseBoost = catchAsync(async (req, res) => {
  const result = await boostService.purchaseBoost(req.user.id, req.body.tier);
  res.status(200).json(result);
});

/**
 * Phase 1.1: Stripe webhook handler.
 *
 * Sync work is now minimal: verify signature, dedupe via WebhookEvent
 * upsert, enqueue `boost.activate` job, return 200. Target latency <50ms.
 *
 * Reply shape echoes the `status` returned by the service (enqueued |
 * duplicate | ignored) for debugging via curl, but Stripe only inspects the
 * status code.
 */
const handleWebhook = async (req, res) => {
  try {
    const signature = req.headers['stripe-signature'];
    const result = await boostService.handleStripeWebhook(req.body, signature);
    res.status(200).json({ received: true, ...result });
  } catch (err) {
    logger.error('Stripe webhook error:', err.message);
    res.status(400).json({
      error: { code: 'WEBHOOK_ERROR', message: err.message },
    });
  }
};

const getBoostStatus = catchAsync(async (req, res) => {
  const status = await boostService.getBoostStatus(req.user.id);
  res.status(200).json(status);
});

module.exports = {
  getPlans, purchaseBoost, handleWebhook, getBoostStatus,
};
