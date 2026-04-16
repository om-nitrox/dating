const mongoose = require('mongoose');
const AppError = require('../utils/AppError');

/**
 * Middleware factory that validates one or more route params are valid MongoDB ObjectIds.
 * Usage: validateObjectId('matchId') or validateObjectId('matchId', 'userId')
 */
const validateObjectId = (...paramNames) => {
  return (req, res, next) => {
    for (const param of paramNames) {
      const value = req.params[param];
      if (value && !mongoose.Types.ObjectId.isValid(value)) {
        return next(new AppError(`Invalid ${param} format`, 400));
      }
    }
    next();
  };
};

module.exports = validateObjectId;
