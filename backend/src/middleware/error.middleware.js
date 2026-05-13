const logger = require('../utils/logger');
const config = require('../config');

/**
 * Global error handler.
 *
 * Response shape (Phase 0.5):
 *   { error: { code: string, message: string, requestId: string } }
 *
 * `requestId` is the value of `req.id` set by the requestId middleware. The
 * frontend already tolerates extra keys; adding `requestId` lets users (or
 * Sentry) attach the same id from the response when filing a bug, making
 * server-side log correlation trivial. In development we additionally
 * surface `error.stack`.
 */
const errorMiddleware = (err, req, res, _next) => {
  let statusCode = err.statusCode || 500;
  let message = err.message || 'Internal server error';
  let code = 'SERVER_ERROR';

  // Mongoose validation error
  if (err.name === 'ValidationError') {
    statusCode = 400;
    code = 'VALIDATION_ERROR';
    const messages = Object.values(err.errors).map((e) => e.message);
    message = messages.join(', ');
  }

  // Mongoose duplicate key
  if (err.code === 11000) {
    statusCode = 409;
    code = 'DUPLICATE_ERROR';
    const field = Object.keys(err.keyValue)[0];
    message = `${field} already exists`;
  }

  // Mongoose cast error (invalid ObjectId)
  if (err.name === 'CastError') {
    statusCode = 400;
    code = 'INVALID_ID';
    message = 'Invalid ID format';
  }

  // JWT errors
  if (err.name === 'JsonWebTokenError') {
    statusCode = 401;
    code = 'INVALID_TOKEN';
    message = 'Invalid token';
  }

  if (err.name === 'TokenExpiredError') {
    statusCode = 401;
    code = 'TOKEN_EXPIRED';
    message = 'Token expired';
  }

  // Operational errors (our AppError instances)
  if (err.isOperational) {
    code = err.code || 'APP_ERROR';
  }

  // Prefer the request-scoped child logger if available so `req_id` is
  // always present on the log record. Falls back to the root logger if the
  // requestId middleware wasn't mounted (e.g. in some unit-test setups).
  const log = req.log || logger;

  // Log server errors with full details
  if (statusCode >= 500) {
    log.error({
      err,
      req_id: req.id,
      method: req.method,
      url: req.originalUrl,
      statusCode,
    }, 'Server error');
  } else if (!err.isOperational) {
    log.warn({
      code,
      message,
      req_id: req.id,
      method: req.method,
      url: req.originalUrl,
      statusCode,
    }, 'Unhandled error');
  }

  const response = {
    error: { code, message, requestId: req.id },
  };

  if (config.nodeEnv === 'development') {
    response.error.stack = err.stack;
  }

  res.status(statusCode).json(response);
};

module.exports = errorMiddleware;
