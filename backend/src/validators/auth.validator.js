const Joi = require('joi');

const signupSchema = Joi.object({
  email: Joi.string().email().required(),
});

const verifyOtpSchema = Joi.object({
  email: Joi.string().email().required(),
  code: Joi.string().length(6).required(),
});

const googleAuthSchema = Joi.object({
  idToken: Joi.string().required(),
});

const refreshTokenSchema = Joi.object({
  refreshToken: Joi.string().required(),
});

module.exports = {
  signupSchema,
  verifyOtpSchema,
  googleAuthSchema,
  refreshTokenSchema,
};
