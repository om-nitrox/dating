const pino = require('pino');
const config = require('../config');

/**
 * Root pino logger.
 *
 * Request-scoped logging pattern (Phase 0.5):
 *   - The `requestId` middleware sets `req.log = logger.child({ req_id })`.
 *   - Handlers and downstream middleware should prefer `req.log.info(...)`
 *     over the root `logger.info(...)` so every line carries the request id.
 *   - For socket handlers, attach a similar child on `socket.data.log`
 *     keyed by `connection_id`.
 *   - Pino `child()` returns a fully-functional logger that inherits all
 *     redaction/serializer config from the parent.
 */
const logger = pino({
  level: config.nodeEnv === 'production' ? 'info' : 'debug',
  transport:
    config.nodeEnv !== 'production'
      ? { target: 'pino-pretty', options: { colorize: true, translateTime: 'HH:MM:ss' } }
      : undefined,
  serializers: {
    err: pino.stdSerializers.err,
    req: pino.stdSerializers.req,
    res: pino.stdSerializers.res,
  },
  redact: {
    paths: [
      // Request — credentials & sensitive payloads
      'req.headers.authorization',
      'req.headers.cookie',
      'req.body.password',
      'req.body.refreshToken',
      'req.body.code',
      'req.body.otp',
      'req.body.idToken',
      // Response — never log freshly-issued tokens
      'res.body.accessToken',
      'res.body.refreshToken',
    ],
    censor: '[REDACTED]',
  },
});

module.exports = logger;
