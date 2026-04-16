const authService = require('../services/auth.service');
const catchAsync = require('../utils/catchAsync');

const signup = catchAsync(async (req, res) => {
  const result = await authService.sendOtp(req.body.email);
  res.status(200).json(result);
});

const verifyOtp = catchAsync(async (req, res) => {
  const { email, code } = req.body;
  const result = await authService.verifyOtp(email, code);
  res.status(200).json(result);
});

const googleAuth = catchAsync(async (req, res) => {
  const result = await authService.googleLogin(req.body.idToken);
  res.status(200).json(result);
});

const refreshToken = catchAsync(async (req, res) => {
  const result = await authService.refreshTokens(req.body.refreshToken);
  res.status(200).json(result);
});

const logout = catchAsync(async (req, res) => {
  await authService.logout(req.user.id);
  res.status(200).json({ message: 'Logged out' });
});

module.exports = { signup, verifyOtp, googleAuth, refreshToken, logout };
