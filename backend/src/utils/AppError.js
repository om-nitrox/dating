class AppError extends Error {
  /**
   * @param {string} message Human-friendly message
   * @param {number} statusCode HTTP status to return
   * @param {string} [code] Optional machine-readable error code (e.g.
   *   `GENDER_REQUIRED`, `NOT_LIKEABLE`, `WEBHOOK_ERROR`). When set, the
   *   global error middleware will surface it in the response envelope.
   */
  constructor(message, statusCode, code) {
    super(message);
    this.statusCode = statusCode;
    this.isOperational = true;
    if (code) this.code = code;
    Error.captureStackTrace(this, this.constructor);
  }
}

module.exports = AppError;
