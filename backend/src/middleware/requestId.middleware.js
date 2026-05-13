// Use the Node built-in crypto.randomUUID — RFC 4122 v4. The `uuid` npm
// package shipped a major version (v13) that is ESM-only and breaks
// `require()` from CommonJS, so prefer the platform primitive here.
const { randomUUID } = require('crypto');

/**
 * Request-ID middleware (Phase 0.5).
 *
 * On every inbound request:
 *   - Read `X-Request-Id` if the caller supplied one (so the frontend can
 *     correlate retries / a Sentry tag back to a backend log line).
 *   - Otherwise, generate a UUIDv4.
 *   - Attach to `req.id` so downstream middleware / handlers can include it
 *     in logs (`logger.child({ req_id })`), error responses, and Sentry tags.
 *   - Echo on the response as `X-Request-Id` so the client can capture it
 *     when reporting a bug.
 *
 * MUST be mounted before all other middleware in `src/app.js` so the ID is
 * available throughout the request lifecycle (security headers, logging,
 * error handlers, etc.).
 *
 * Validation: incoming X-Request-Id is length-capped to 128 chars and
 * restricted to URL-safe characters to prevent log-injection / header
 * smuggling.
 */
const INCOMING_ID_PATTERN = /^[A-Za-z0-9_\-.:]+$/;
const MAX_INCOMING_ID_LEN = 128;

const isValidIncomingId = (raw) => (
  typeof raw === 'string'
  && raw.length > 0
  && raw.length <= MAX_INCOMING_ID_LEN
  && INCOMING_ID_PATTERN.test(raw)
);

const requestIdMiddleware = (req, res, next) => {
  const incoming = req.headers['x-request-id'];
  const id = isValidIncomingId(incoming) ? incoming : randomUUID();

  req.id = id;
  // Bind a child logger so any handler can log with `req.log.info(...)` and
  // get the req_id automatically. Lazy-required so this module stays
  // pure-CJS at top-level (avoids a circular dep w/ logger if it ever
  // imports request context).
  // eslint-disable-next-line global-require
  const logger = require('../utils/logger');
  req.log = logger.child({ req_id: id });

  res.setHeader('X-Request-Id', id);
  next();
};

module.exports = requestIdMiddleware;
module.exports.isValidIncomingId = isValidIncomingId;
