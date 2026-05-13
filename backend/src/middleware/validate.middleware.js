const AppError = require('../utils/AppError');

const validate = (schema) => (req, res, next) => {
  const { error, value } = schema.validate(req.body, {
    abortEarly: false,
    stripUnknown: true,
  });

  if (error) {
    const details = error.details.map((d) => d.message);
    return next(new AppError(details.join(', '), 400));
  }

  req.body = value;
  req.cleanBody = value;
  next();
};

/**
 * Validate against the sanitized query (req.cleanQuery — see
 * sanitize.middleware). The validated output replaces req.cleanQuery so
 * downstream handlers consume the coerced shape.  We deliberately do NOT
 * touch req.query (read-only in Express 5).
 */
const validateQuery = (schema) => (req, res, next) => {
  const source = req.cleanQuery || req.query || {};
  const { error, value } = schema.validate(source, {
    abortEarly: false,
    stripUnknown: true,
  });

  if (error) {
    const details = error.details.map((d) => d.message);
    return next(new AppError(details.join(', '), 400));
  }

  req.cleanQuery = value;
  next();
};

module.exports = { validate, validateQuery };
