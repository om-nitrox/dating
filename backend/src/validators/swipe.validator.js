// Phase 0.3 note: spec-side equivalent is ./generated/requests.js `likeUser` /
// `skipUser` (both share the `UserIdRequest` body schema). The Joi version
// stays here so route mounts don't change; it accepts the same shape.
const Joi = require('joi');

const swipeSchema = Joi.object({
  userId: Joi.string().required(),
});

module.exports = { swipeSchema };
