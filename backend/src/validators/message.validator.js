const Joi = require('joi');

const sendMessageSchema = Joi.object({
  matchId: Joi.string().required(),
  text: Joi.string().trim().max(2000).required(),
});

module.exports = { sendMessageSchema };
