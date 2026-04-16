const Stripe = require('stripe');
const config = require('./index');

const stripe = config.stripeSecretKey
  ? new Stripe(config.stripeSecretKey)
  : null;

module.exports = stripe;
