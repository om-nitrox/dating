// Phase 0.3 note: spec-side equivalent is ./generated/requests.js `deleteAccount`
// (uses AccountDeleteRequest). The Joi version stays for parity with the other
// validators.
const Joi = require('joi');

const deleteAccountSchema = Joi.object({
  confirmation: Joi.string().valid('DELETE_MY_ACCOUNT').required(),
});

module.exports = { deleteAccountSchema };
