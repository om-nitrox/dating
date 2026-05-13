// Phase 0.3 note: spec-side equivalent is ./generated/requests.js `purchaseBoost`
// (uses `BoostPurchaseRequest`). The Joi version stays for consistency with
// the other validators; both pull from the canonical BOOST_PAID_TIERS list.
const Joi = require('joi');
const { BOOST_PAID_TIERS } = require('../domain/taxonomies');

const purchaseBoostSchema = Joi.object({
  tier: Joi.string().valid(...BOOST_PAID_TIERS).required(),
});

module.exports = { purchaseBoostSchema };
