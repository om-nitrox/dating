const { OAuth2Client } = require('google-auth-library');
const User = require('../models/User');
const Otp = require('../models/Otp');
const config = require('../config');
const { generateOtp, sendOtpEmail, hashOtp } = require('../utils/otp');
const {
  signAccessToken, signRefreshToken, verifyRefreshToken, hashRefreshToken,
} = require('../utils/token');
const { getRedis } = require('../config/redis');
const AppError = require('../utils/AppError');
const logger = require('../utils/logger');

const googleClient = config.googleClientId
  ? new OAuth2Client(config.googleClientId)
  : null;

const MIN_AGE_MS = 18 * 365.25 * 24 * 60 * 60 * 1000;
const MAX_SESSIONS = 10;

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

  // Remove any existing OTPs for this email. Persist only the HMAC of the
  // code so a DB dump never exposes a valid OTP.
  await Otp.deleteMany({ email });
  await Otp.create({ email, codeHash: hashOtp(code), expiresAt });
  await sendOtpEmail(email, code);

  return { message: 'OTP sent successfully' };
};

const verifyOtp = async (email, code, dateOfBirth) => {
  // Look up by hashed code — never compare plaintext against stored values.
  const otp = await Otp.findOne({ email, codeHash: hashOtp(code) });

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
 * Parse a refresh-token JWT's exp claim into a JS Date.
 */
const expFromDecoded = (decoded) => {
  if (decoded.exp && Number.isFinite(decoded.exp)) {
    return new Date(decoded.exp * 1000);
  }
  return new Date(Date.now() + 7 * 24 * 60 * 60 * 1000);
};

/**
 * Blacklist an access-token jti for the remainder of its life. Best-effort —
 * if Redis is unavailable the token will simply expire naturally.
 */
const blacklistAccessJti = async (jti, exp) => {
  if (!jti || !exp) return;
  const ttl = exp - Math.floor(Date.now() / 1000);
  if (ttl <= 0) return;
  try {
    const redis = getRedis();
    await redis.set(`blacklist:${jti}`, '1', 'EX', ttl);
  } catch (_) {
    // Non-fatal — token will expire naturally
  }
};

/**
 * Atomic refresh-token rotation with per-session reuse detection.
 *
 * On a valid refresh we update the session row in-place. On mismatch for a
 * known-good jti we revoke only THAT session (not all sessions), so a
 * compromised device doesn't kick the user out of every other login.
 *
 * Backward-compat: if the user has a legacy `refreshToken` string but an
 * empty `refreshSessions` array, accept it once and migrate into the array.
 */
const refreshTokens = async (token) => {
  let decoded;
  try {
    decoded = verifyRefreshToken(token);
  } catch {
    throw new AppError('Invalid refresh token', 401);
  }

  const hashedIncoming = hashRefreshToken(token);
  const { token: newRefreshToken, jti: newJti } = signRefreshToken(decoded.id);
  const newHash = hashRefreshToken(newRefreshToken);
  const newExpiresAt = expFromDecoded(verifyRefreshToken(newRefreshToken));

  // Resolve which session row matches.  If the token has a jti, try to swap
  // that specific entry. Otherwise (legacy), match on the hash.
  const incomingJti = decoded.jti;

  let updated;

  if (incomingJti) {
    updated = await User.findOneAndUpdate(
      {
        _id: decoded.id,
        refreshSessions: {
          $elemMatch: { jti: incomingJti, hash: hashedIncoming },
        },
      },
      {
        $set: {
          'refreshSessions.$.jti': newJti,
          'refreshSessions.$.hash': newHash,
          'refreshSessions.$.createdAt': new Date(),
          'refreshSessions.$.expiresAt': newExpiresAt,
        },
      },
      { new: true },
    );
  }

  // Backward-compat: legacy single-token storage.
  if (!updated) {
    updated = await User.findOneAndUpdate(
      {
        _id: decoded.id,
        refreshToken: hashedIncoming,
      },
      {
        $set: { refreshToken: null },
        $push: {
          refreshSessions: {
            $each: [
              {
                jti: newJti,
                hash: newHash,
                createdAt: new Date(),
                expiresAt: newExpiresAt,
              },
            ],
            $slice: -MAX_SESSIONS,
          },
        },
      },
      { new: true },
    );
  }

  if (!updated) {
    // Reuse detected for a known jti — revoke ONLY that session. If the jti
    // isn't in the user's session list there's nothing to revoke.
    if (incomingJti) {
      await User.updateOne(
        { _id: decoded.id },
        { $pull: { refreshSessions: { jti: incomingJti } } },
      );
      logger.warn({ userId: decoded.id, jti: incomingJti }, 'Refresh-token reuse detected; revoked single session');

      // Spec fix 25: when a replay is detected, also blacklist the
      // associated access-jti (the JWT we issued alongside this refresh)
      // for the remainder of its lifetime. Belt-and-braces with the
      // per-session revoke above.
      try {
        const redis = getRedis();
        await redis.set(
          `blacklist:${incomingJti}`,
          '1',
          'EX',
          config.jwtAccessExpirySeconds,
        );
      } catch (_) { /* non-fatal */ }
    }
    throw new AppError('Invalid refresh token', 401);
  }

  if (updated.banned) {
    throw new AppError('Your account has been suspended', 403);
  }

  // Cap the array length (oldest evicted) — primarily defensive in case the
  // legacy migration path pushed beyond MAX_SESSIONS.
  if (updated.refreshSessions.length > MAX_SESSIONS) {
    await User.updateOne(
      { _id: decoded.id },
      {
        $push: {
          refreshSessions: {
            $each: [],
            $slice: -MAX_SESSIONS,
          },
        },
      },
    );
  }

  const accessToken = signAccessToken(updated._id, updated.gender);

  return { accessToken, refreshToken: newRefreshToken };
};

/**
 * Logout: clear the calling device's refresh session and blacklist the
 * current access token's jti.
 */
const logout = async (userId, accessTokenMeta) => {
  // Best-effort: we don't know the refresh jti from the access token, so
  // clear the legacy single-slot and rely on the caller to discard the
  // local refresh token. To revoke a SPECIFIC session, callers should hit
  // a per-session revoke endpoint (future work).
  await User.findByIdAndUpdate(userId, { refreshToken: null });

  await blacklistAccessJti(accessTokenMeta?.jti, accessTokenMeta?.exp);
};

/**
 * Issue access + refresh tokens, append the refresh session, return auth response.
 */
const issueTokens = async (user, isNewUser) => {
  const accessToken = signAccessToken(user._id, user.gender);
  const { token: refreshToken, jti } = signRefreshToken(user._id);
  const hash = hashRefreshToken(refreshToken);
  const expiresAt = expFromDecoded(verifyRefreshToken(refreshToken));

  // Append to the bounded session array. We cap at MAX_SESSIONS so the
  // oldest gets evicted automatically.
  await User.updateOne(
    { _id: user._id },
    {
      $push: {
        refreshSessions: {
          $each: [{
            jti,
            hash,
            createdAt: new Date(),
            expiresAt,
          }],
          $slice: -MAX_SESSIONS,
        },
      },
    },
  );

  // Reload to get the up-to-date doc (without refreshSessions in the response).
  const fresh = await User.findById(user._id);

  return {
    accessToken,
    refreshToken,
    user: sanitizeUser(fresh || user),
    isNewUser,
  };
};

const sanitizeUser = (user) => {
  const obj = user.toObject ? user.toObject() : user;
  delete obj.refreshToken;
  delete obj.refreshSessions;
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
  blacklistAccessJti,
};
