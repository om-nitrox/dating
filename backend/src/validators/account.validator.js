const Joi = require('joi');

const deleteAccountSchema = Joi.object({
  confirmation: Joi.string().valid('DELETE_MY_ACCOUNT').required(),
});

module.exports = { deleteAccountSchema };
