const authService = require('../services/auth.service');
const { upsertFcmToken, removeFcmToken } = require('../services/notification.service');
const catchAsync = require('../utils/catchAsync');

const signup = catchAsync(async (req, res) => {
  const result = await authService.sendOtp(req.body.email);
  res.status(200).json(result);
});

const verifyOtp = catchAsync(async (req, res) => {
  const { email, code, dateOfBirth } = req.body;
  const result = await authService.verifyOtp(email, code, dateOfBirth);

  // Register FCM token if provided with the login request
  const deviceId = req.headers['x-device-id'];
  const fcmToken = req.headers['x-fcm-token'];
  if (deviceId && fcmToken) {
    await upsertFcmToken(result.user._id.toString(), fcmToken, deviceId);
  }

  res.status(200).json(result);
});

const googleAuth = catchAsync(async (req, res) => {
  const { idToken, dateOfBirth } = req.body;
  const result = await authService.googleLogin(idToken, dateOfBirth);

  const deviceId = req.headers['x-device-id'];
  const fcmToken = req.headers['x-fcm-token'];
  if (deviceId && fcmToken) {
    await upsertFcmToken(result.user._id.toString(), fcmToken, deviceId);
  }

  res.status(200).json(result);
});

const refreshToken = catchAsync(async (req, res) => {
  const result = await authService.refreshTokens(req.body.refreshToken);

  const deviceId = req.headers['x-device-id'];
  const fcmToken = req.headers['x-fcm-token'];
  if (deviceId && fcmToken) {
    await upsertFcmToken(result.user?._id?.toString() ?? req.body.userId, fcmToken, deviceId);
  }

  res.status(200).json(result);
});

const logout = catchAsync(async (req, res) => {
  const deviceId = req.headers['x-device-id'];

  await Promise.all([
    authService.logout(req.user.id, { jti: req.user.jti, exp: req.user.tokenExp }),
    deviceId ? removeFcmToken(req.user.id, deviceId) : Promise.resolve(),
  ]);

  res.status(200).json({ message: 'Logged out' });
});

module.exports = {
  signup, verifyOtp, googleAuth, refreshToken, logout,
};
