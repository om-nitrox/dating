const User = require('../models/User');
const WebhookEvent = require('../models/WebhookEvent');
const stripe = require('../config/stripe');
const config = require('../config');
const AppError = require('../utils/AppError');
const logger = require('../utils/logger');

// Plans per BACKEND_API.md §7. `duration*` and `price*` carry both the raw
// numeric value (frontend uses `priceCents`/`durationMinutes`) and the
// pre-formatted strings the spec shows in BoostPlanModel.
const BOOST_PLANS = [
  {
    id: 'bronze-30',
    name: 'Bronze',
    tier: 'bronze',
    durationMinutes: 30,
    priceCents: 99,
    currency: 'USD',
    label: 'Try it out',
  },
  {
    id: 'silver-60',
    name: 'Silver',
    tier: 'silver',
    durationMinutes: 60,
    priceCents: 299,
    currency: 'USD',
    label: 'Most popular',
  },
  {
    id: 'gold-180',
    name: 'Gold',
    tier: 'gold',
    durationMinutes: 180,
    priceCents: 599,
    currency: 'USD',
    label: 'Best value',
  },
];

const formatPrice = (cents, currency) => {
  const symbol = currency === 'USD' ? '$' : '';
  return `${symbol}${(cents / 100).toFixed(2)}`;
};

const formatDuration = (minutes) => {
  if (minutes >= 60 && minutes % 60 === 0) {
    const hours = minutes / 60;
    return `${hours} hr`;
  }
  return `${minutes} min`;
};

const decorateBoostPlan = (plan) => ({
  ...plan,
  // Keep legacy keys so any old frontend code that read them still works,
  // but the canonical fields are the ones defined in BoostPlanModel.
  price: formatPrice(plan.priceCents, plan.currency),
  duration: formatDuration(plan.durationMinutes),
});

const getPlanByTier = (tier) => BOOST_PLANS.find((p) => p.tier === tier);

const getPlans = () => BOOST_PLANS.map(decorateBoostPlan);

const purchaseBoost = async (userId, tier) => {
  const plan = getPlanByTier(tier);
  if (!plan) throw new AppError('Invalid boost tier', 400);

  // If Stripe isn't configured (dev), return empty url so the frontend
  // silently skips the launch (documented behaviour in BACKEND_API.md §7).
  if (!stripe) {
    logger.warn('Stripe not configured — returning empty checkout URL');
    return { url: '' };
  }

  const session = await stripe.checkout.sessions.create({
    payment_method_types: ['card'],
    line_items: [
      {
        price_data: {
          currency: plan.currency.toLowerCase(),
          product_data: {
            name: `Reverse Match Boost — ${plan.name}`,
          },
          unit_amount: plan.priceCents,
        },
        quantity: 1,
      },
    ],
    mode: 'payment',
    metadata: {
      userId: userId.toString(),
      tier,
      durationMinutes: plan.durationMinutes.toString(),
    },
    success_url: `${config.appBaseUrl}/api/v1/boost/success?session_id={CHECKOUT_SESSION_ID}`,
    cancel_url: `${config.appBaseUrl}/api/v1/boost/cancel`,
  });

  return { url: session.url, sessionId: session.id };
};

const activateBoost = async (userId, tier, durationMinutes) => {
  const expiry = new Date(Date.now() + durationMinutes * 60 * 1000);

  await User.findByIdAndUpdate(userId, {
    boostLevel: tier,
    boostExpiry: expiry,
  });

  return expiry;
};

const handleStripeWebhook = async (rawBody, signature) => {
  if (!stripe) throw new AppError('Payments not configured', 500);

  const event = stripe.webhooks.constructEvent(
    rawBody,
    signature,
    config.stripeWebhookSecret,
  );

  // Atomic dedup: a single upsert closes the TOCTOU window between
  // findOne+create. `upsertedCount === 1` means THIS process inserted the
  // event row and is the one allowed to apply side effects.
  const upsertRes = await WebhookEvent.updateOne(
    { eventId: event.id },
    {
      $setOnInsert: {
        eventId: event.id,
        type: event.type,
        processedAt: new Date(),
      },
    },
    { upsert: true },
  );

  if (!upsertRes.upsertedCount) {
    logger.info(`Stripe webhook already processed: ${event.id}`);
    return;
  }

  if (event.type === 'checkout.session.completed') {
    const session = event.data.object;
    const { userId, tier, durationMinutes } = session.metadata || {};

    if (userId && tier && durationMinutes) {
      await activateBoost(userId, tier, parseInt(durationMinutes, 10));
      logger.info(`Boost activated: userId=${userId}, tier=${tier}, durationMinutes=${durationMinutes}`);
    }
  }
};

/**
 * Get active boost status for a user.
 * Spec shape: { active, tier, expiresAt }.
 */
const getBoostStatus = async (userId) => {
  const user = await User.findById(userId).select('boostLevel boostExpiry');
  if (!user) throw new AppError('User not found', 404);

  const isActive = user.boostLevel
    && user.boostLevel !== 'none'
    && user.boostExpiry
    && user.boostExpiry > new Date();

  return {
    active: !!isActive,
    tier: isActive ? user.boostLevel : null,
    expiresAt: isActive ? user.boostExpiry.toISOString() : null,
  };
};

module.exports = {
  getPlans, purchaseBoost, activateBoost, handleStripeWebhook, getBoostStatus,
};
