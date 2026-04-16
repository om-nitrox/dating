const { Router } = require('express');
const authController = require('../controllers/auth.controller');
const { validate } = require('../middleware/validate.middleware');
const { authLimiter, otpVerifyLimiter, otpSendLimiter } = require('../middleware/rateLimiter.middleware');
const auth = require('../middleware/auth.middleware');
const {
  signupSchema,
  verifyOtpSchema,
  googleAuthSchema,
  refreshTokenSchema,
} = require('../validators/auth.validator');

const router = Router();

router.post('/signup', authLimiter, otpSendLimiter, validate(signupSchema), authController.signup);
router.post('/verify-otp', authLimiter, otpVerifyLimiter, validate(verifyOtpSchema), authController.verifyOtp);
router.post('/google', authLimiter, validate(googleAuthSchema), authController.googleAuth);
router.post('/refresh-token', validate(refreshTokenSchema), authController.refreshToken);
router.post('/logout', auth, authController.logout);

module.exports = router;
