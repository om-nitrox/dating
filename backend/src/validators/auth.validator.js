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
