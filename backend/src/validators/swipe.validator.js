const Joi = require('joi');

const swipeSchema = Joi.object({
  userId: Joi.string().required(),
});

module.exports = { swipeSchema };
