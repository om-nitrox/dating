const pino = require('pino');
const config = require('../config');

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
