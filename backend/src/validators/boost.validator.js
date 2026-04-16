const Joi = require('joi');

const purchaseBoostSchema = Joi.object({
  tier: Joi.string().valid('bronze', 'silver', 'gold').required(),
});

module.exports = { purchaseBoostSchema };
