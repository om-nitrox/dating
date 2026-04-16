const User = require('../models/User');
const WebhookEvent = require('../models/WebhookEvent');
const stripe = require('../config/stripe');
const config = require('../config');
const AppError = require('../utils/AppError');
const logger = require('../utils/logger');

const BOOST_PLANS = {
  bronze: { price: 499, duration: 1, label: 'Bronze - 1 Day' },
  silver: { price: 999, duration: 3, label: 'Silver - 3 Days' },
  gold: { price: 1999, duration: 7, label: 'Gold - 7 Days' },
};

const getPlans = () => {
  return Object.entries(BOOST_PLANS).map(([tier, plan]) => ({
    tier,
    price: plan.price, // in cents
    duration: plan.duration,
    label: plan.label,
  }));
};

const purchaseBoost = async (userId, tier) => {
  if (!stripe) throw new AppError('Payments not configured', 500);

  const plan = BOOST_PLANS[tier];
  if (!plan) throw new AppError('Invalid boost tier', 400);

  const session = await stripe.checkout.sessions.create({
    payment_method_types: ['card'],
    line_items: [
      {
        price_data: {
          currency: 'usd',
          product_data: {
            name: `Reverse Match Boost - ${plan.label}`,
          },
          unit_amount: plan.price,
        },
        quantity: 1,
      },
    ],
    mode: 'payment',
    metadata: {
      userId: userId.toString(),
      tier,
      duration: plan.duration.toString(),
    },
    success_url: `${config.appBaseUrl}/api/v1/boost/success?session_id={CHECKOUT_SESSION_ID}`,
    cancel_url: `${config.appBaseUrl}/api/v1/boost/cancel`,
  });

  return { sessionId: session.id, url: session.url };
};

const activateBoost = async (userId, tier, durationDays) => {
  const expiry = new Date();
  expiry.setDate(expiry.getDate() + durationDays);

  await User.findByIdAndUpdate(userId, {
    boostLevel: tier,
    boostExpiry: expiry,
  });
};

const handleStripeWebhook = async (rawBody, signature) => {
  if (!stripe) throw new AppError('Payments not configured', 500);

  const event = stripe.webhooks.constructEvent(
    rawBody,
    signature,
    config.stripeWebhookSecret
  );

  // Idempotency check — skip already-processed events
  const existing = await WebhookEvent.findOne({ eventId: event.id });
  if (existing) {
    logger.info(`Stripe webhook already processed: ${event.id}`);
    return;
  }

  if (event.type === 'checkout.session.completed') {
    const session = event.data.object;
    const { userId, tier, duration } = session.metadata;

    if (userId && tier && duration) {
      await activateBoost(userId, tier, parseInt(duration));
      logger.info(`Boost activated: userId=${userId}, tier=${tier}, duration=${duration}`);
    }
  }

  // Record processed event
  await WebhookEvent.create({ eventId: event.id, type: event.type });
};

/**
 * Get active boost status for a user.
 * Used for "restore purchases" — checks if the user has an active boost.
 */
const getBoostStatus = async (userId) => {
  const user = await User.findById(userId).select('boostLevel boostExpiry');
  if (!user) throw new AppError('User not found', 404);

  const isActive =
    user.boostLevel !== 'none' &&
    user.boostExpiry &&
    user.boostExpiry > new Date();

  return {
    boostLevel: isActive ? user.boostLevel : 'none',
    boostExpiry: isActive ? user.boostExpiry : null,
    isActive,
  };
};

module.exports = { getPlans, purchaseBoost, activateBoost, handleStripeWebhook, getBoostStatus };
