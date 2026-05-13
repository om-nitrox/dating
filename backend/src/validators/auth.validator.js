// Phase 0.3 note: the spec-side equivalents of these validators are
// generated from docs/api/openapi.yaml into ./generated/requests.js
// (`requestEmailOtp`, `verifyEmailOtp`, `googleSignIn`, `refreshTokens`).
// The Joi schemas below stay because:
//   - they accept `dateOfBirth` as a side-channel field the OpenAPI spec
//     does not yet declare (it's collected during onboarding via
//     PUT /profile, but legacy clients still send it here);
//   - they use Joi's `stripUnknown` so unknown keys don't 400 today.
// When `dateOfBirth` is dropped from the contract these can be replaced
// with `zodValidate(requests.<op>)`.
const Joi = require('joi');

const signupSchema = Joi.object({
  email: Joi.string().email().required(),
});

const verifyOtpSchema = Joi.object({
  email: Joi.string().email().required(),
  code: Joi.string().length(6).required(),
  dateOfBirth: Joi.string().isoDate().optional(),
}).options({ stripUnknown: true });

const googleAuthSchema = Joi.object({
  idToken: Joi.string().required(),
  dateOfBirth: Joi.string().isoDate().optional(),
}).options({ stripUnknown: true });

const refreshTokenSchema = Joi.object({
  refreshToken: Joi.string().required(),
}).options({ stripUnknown: true });

module.exports = {
  signupSchema,
  verifyOtpSchema,
  googleAuthSchema,
  refreshTokenSchema,
};
