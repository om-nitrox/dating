const Sentry = require('@sentry/node');
const config = require('./index');
const logger = require('../utils/logger');

const initSentry = () => {
  if (!config.sentryDsn) {
    logger.warn('Sentry DSN not set, error tracking disabled');
    return;
  }

  Sentry.init({
    dsn: config.sentryDsn,
    environment: config.nodeEnv,
    tracesSampleRate: config.nodeEnv === 'production' ? 0.1 : 1.0,
    beforeSend(event) {
      // Scrub sensitive data
      if (event.request?.headers) {
        delete event.request.headers.authorization;
        delete event.request.headers.cookie;
      }
      return event;
    },
  });

  logger.info('Sentry initialized');
};

module.exports = { initSentry, Sentry };
