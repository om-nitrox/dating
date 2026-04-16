const { OAuth2Client } = require('google-auth-library');
const User = require('../models/User');
const Otp = require('../models/Otp');
const config = require('../config');
const { generateOtp, sendOtpEmail } = require('../utils/otp');
const { signAccessToken, signRefreshToken, verifyRefreshToken, hashRefreshToken } = require('../utils/token');
const AppError = require('../utils/AppError');

const googleClient = config.googleClientId
  ? new OAuth2Client(config.googleClientId)
  : null;

const sendOtp = async (email) => {
  const code = generateOtp();
  const expiresAt = new Date(Date.now() + config.otpExpiryMinutes * 60 * 1000);

  // Remove any existing OTPs for this email
  await Otp.deleteMany({ email });

  await Otp.create({ email, code, expiresAt });
  await sendOtpEmail(email, code);

  return { message: 'OTP sent successfully' };
};

const verifyOtp = async (email, code) => {
  const otp = await Otp.findOne({ email, code });

  if (!otp) {
    throw new AppError('Invalid or expired OTP', 400);
  }

  if (otp.expiresAt < new Date()) {
    await Otp.deleteMany({ email });
    throw new AppError('OTP expired', 400);
  }

  // Clean up used OTP
  await Otp.deleteMany({ email });

  // Find or create user
  let user = await User.findOne({ email });
  let isNewUser = false;

  if (!user) {
    user = await User.create({ email });
    isNewUser = true;
  }

  return issueTokens(user, isNewUser);
};

const googleLogin = async (idToken) => {
  if (!googleClient) {
    throw new AppError('Google login not configured', 500);
  }

  const ticket = await googleClient.verifyIdToken({
    idToken,
    audience: config.googleClientId,
  });

  const payload = ticket.getPayload();
  const { sub: googleId, email, name } = payload;

  let user = await User.findOne({ $or: [{ googleId }, { email }] });
  let isNewUser = false;

  if (!user) {
    user = await User.create({ email, googleId, name });
    isNewUser = true;
  } else if (!user.googleId) {
    user.googleId = googleId;
    await user.save();
  }

  return issueTokens(user, isNewUser);
};

const refreshTokens = async (token) => {
  let decoded;
  try {
    decoded = verifyRefreshToken(token);
  } catch {
    throw new AppError('Invalid refresh token', 401);
  }

  const user = await User.findById(decoded.id);

  // Compare hashed token
  const hashedIncoming = hashRefreshToken(token);
  if (!user || user.refreshToken !== hashedIncoming) {
    // Possible token reuse attack — invalidate all tokens for this user
    if (user) {
      user.refreshToken = null;
      await user.save();
    }
    throw new AppError('Invalid refresh token', 401);
  }

  const accessToken = signAccessToken(user._id, user.gender);
  const refreshToken = signRefreshToken(user._id);

  // Store hash of new refresh token
  user.refreshToken = hashRefreshToken(refreshToken);
  await user.save();

  return { accessToken, refreshToken };
};

const logout = async (userId) => {
  await User.findByIdAndUpdate(userId, { refreshToken: null });
};

/**
 * Issue access + refresh tokens, store hashed refresh token, return auth response.
 */
const issueTokens = async (user, isNewUser) => {
  const accessToken = signAccessToken(user._id, user.gender);
  const refreshToken = signRefreshToken(user._id);

  // Store SHA-256 hash of refresh token (not plain text)
  user.refreshToken = hashRefreshToken(refreshToken);
  await user.save();

  return {
    accessToken,
    refreshToken,
    user: sanitizeUser(user),
    isNewUser,
  };
};

const sanitizeUser = (user) => {
  const obj = user.toObject();
  delete obj.refreshToken;
  delete obj.__v;
  return obj;
};

module.exports = {
  sendOtp,
  verifyOtp,
  googleLogin,
  refreshTokens,
  logout,
};
