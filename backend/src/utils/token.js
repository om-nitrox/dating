const jwt = require('jsonwebtoken');
const crypto = require('crypto');
const config = require('../config');

const signAccessToken = (userId, gender) => jwt.sign(
  { id: userId, gender, jti: crypto.randomUUID() },
  config.jwtAccessSecret,
  { expiresIn: config.jwtAccessExpiry },
);

/**
 * Refresh tokens carry their own jti so we can identify which session-row
 * to update on rotation. The caller stores the jti + HMAC of the token in
 * User.refreshSessions[].
 */
const signRefreshToken = (userId, jti = crypto.randomUUID()) => {
  const token = jwt.sign(
    { id: userId, jti },
    config.jwtRefreshSecret,
    { expiresIn: config.jwtRefreshExpiry },
  );
  return { token, jti };
};

const verifyAccessToken = (token) => jwt.verify(token, config.jwtAccessSecret);

const verifyRefreshToken = (token) => jwt.verify(token, config.jwtRefreshSecret);

/**
 * Hash a refresh token using SHA-256 for secure storage.
 * Refresh tokens are already high-entropy JWTs, so SHA-256 is sufficient.
 */
const hashRefreshToken = (token) => crypto.createHash('sha256').update(token).digest('hex');

module.exports = {
  signAccessToken,
  signRefreshToken,
  verifyAccessToken,
  verifyRefreshToken,
  hashRefreshToken,
};
