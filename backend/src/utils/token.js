const jwt = require('jsonwebtoken');
const crypto = require('crypto');
const config = require('../config');

const signAccessToken = (userId, gender) => {
  return jwt.sign(
    { id: userId, gender, jti: crypto.randomUUID() },
    config.jwtAccessSecret,
    { expiresIn: config.jwtAccessExpiry }
  );
};

const signRefreshToken = (userId) => {
  return jwt.sign(
    { id: userId },
    config.jwtRefreshSecret,
    { expiresIn: config.jwtRefreshExpiry }
  );
};

const verifyAccessToken = (token) => {
  return jwt.verify(token, config.jwtAccessSecret);
};

const verifyRefreshToken = (token) => {
  return jwt.verify(token, config.jwtRefreshSecret);
};

/**
 * Hash a refresh token using SHA-256 for secure storage.
 * Refresh tokens are already high-entropy JWTs, so SHA-256 is sufficient.
 */
const hashRefreshToken = (token) => {
  return crypto.createHash('sha256').update(token).digest('hex');
};

module.exports = {
  signAccessToken,
  signRefreshToken,
  verifyAccessToken,
  verifyRefreshToken,
  hashRefreshToken,
};
