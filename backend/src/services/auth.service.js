const { OAuth2Client } = require('google-auth-library');
const User = require('../models/User');
const Otp = require('../models/Otp');
const config = require('../config');
const { generateOtp, sendOtpEmail } = require('../utils/otp');
const {
  signAccessToken, signRefreshToken, verifyRefreshToken, hashRefreshToken,
} = require('../utils/token');
const { getRedis } = require('../config/redis');
const AppError = require('../utils/AppError');

const googleClient = config.googleClientId
  ? new OAuth2Client(config.googleClientId)
  : null;

const MIN_AGE_MS = 18 * 365.25 * 24 * 60 * 60 * 1000;

const validateAge = (dateOfBirth) => {
  const dob = new Date(dateOfBirth);
  if (Number.isNaN(dob.getTime())) {
    throw new AppError('Invalid date of birth', 400);
  }
  if (Date.now() - dob.getTime() < MIN_AGE_MS) {
    throw new AppError('You must be 18 or older to use Reverse Match', 400);
  }
  return dob;
};

const sendOtp = async (email) => {
  const code = generateOtp();
  const expiresAt = new Date(Date.now() + config.otpExpiryMinutes * 60 * 1000);

  // Remove any existing OTPs for this email
  await Otp.deleteMany({ email });
  await Otp.create({ email, code, expiresAt });
  await sendOtpEmail(email, code);

  return { message: 'OTP sent successfully' };
};

const verifyOtp = async (email, code, dateOfBirth) => {
  const otp = await Otp.findOne({ email, code });

  if (!otp) {
    throw new AppError('Invalid or expired OTP', 400);
  }

  if (otp.expiresAt < new Date()) {
    await Otp.deleteMany({ email });
    throw new AppError('OTP expired', 400);
  }

  await Otp.deleteMany({ email });

  let user = await User.findOne({ email });
  let isNewUser = false;

  if (!user) {
    // DOB is optional at signup; users provide it during the onboarding flow
    // (see PUT /profile). When supplied here we still validate the 18+ rule.
    const dob = dateOfBirth ? validateAge(dateOfBirth) : undefined;
    user = await User.create(dob ? { email, dob } : { email });
    isNewUser = true;
  }

  if (user.banned) {
    throw new AppError('Your account has been suspended', 403);
  }

  return issueTokens(user, isNewUser);
};

const googleLogin = async (idToken, dateOfBirth) => {
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
    // DOB is optional at signup; collected later during onboarding via PUT /profile.
    const dob = dateOfBirth ? validateAge(dateOfBirth) : undefined;
    const fields = { email, googleId, name };
    if (dob) fields.dob = dob;
    user = await User.create(fields);
    isNewUser = true;
  } else if (!user.googleId) {
    user.googleId = googleId;
    await user.save();
  }

  if (user.banned) {
    throw new AppError('Your account has been suspended', 403);
  }

  return issueTokens(user, isNewUser);
};

/**
 * Atomic refresh token rotation using findOneAndUpdate.
 * Only one concurrent request with the same token can succeed —
 * the filter { refreshToken: oldHash } ensures only one wins the race.
 */
const refreshTokens = async (token) => {
  let decoded;
  try {
    decoded = verifyRefreshToken(token);
  } catch {
    throw new AppError('Invalid refresh token', 401);
  }

  const hashedIncoming = hashRefreshToken(token);
  const newRefreshToken = signRefreshToken(decoded.id);
  const newHash = hashRefreshToken(newRefreshToken);

  // Atomic swap: only succeeds if the old hash is still in the DB
  const user = await User.findOneAndUpdate(
    { _id: decoded.id, refreshToken: hashedIncoming },
    { refreshToken: newHash },
    { new: true },
  );

  if (!user) {
    // Token already consumed — possible replay attack; invalidate all tokens
    await User.findByIdAndUpdate(decoded.id, { refreshToken: null });
    throw new AppError('Invalid refresh token', 401);
  }

  if (user.banned) {
    throw new AppError('Your account has been suspended', 403);
  }

  const accessToken = signAccessToken(user._id, user.gender);

  return { accessToken, refreshToken: newRefreshToken };
};

/**
 * Logout: clear refresh token and blacklist the current access token's jti.
 */
const logout = async (userId, accessTokenMeta) => {
  await User.findByIdAndUpdate(userId, { refreshToken: null });

  // Blacklist the access token so it can't be reused until it naturally expires
  if (accessTokenMeta?.jti && accessTokenMeta?.exp) {
    const ttl = accessTokenMeta.exp - Math.floor(Date.now() / 1000);
    if (ttl > 0) {
      try {
        const redis = getRedis();
        await redis.set(`blacklist:${accessTokenMeta.jti}`, '1', 'EX', ttl);
      } catch (_) {
        // Non-fatal — token will expire naturally
      }
    }
  }
};

/**
 * Issue access + refresh tokens, store hashed refresh token, return auth response.
 */
const issueTokens = async (user, isNewUser) => {
  const accessToken = signAccessToken(user._id, user.gender);
  const refreshToken = signRefreshToken(user._id);

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
  delete obj.fcmTokens;
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
