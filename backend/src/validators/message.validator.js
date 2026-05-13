// Phase 0.3 note: spec-side equivalent is ./generated/requests.js `sendMessage`
// (uses `SendMessageRequest`, which enforces 24-char-hex matchId + text 1..2000).
// The Joi version stays because it accepts a 24-char-hex OR any non-empty
// string and `Joi.trim()` mutates the body in-place; equivalent zod call is
// `text.trim().min(1).max(2000)`.
const Joi = require('joi');

const sendMessageSchema = Joi.object({
  matchId: Joi.string().required(),
  text: Joi.string().trim().max(2000).required(),
});

module.exports = { sendMessageSchema };
