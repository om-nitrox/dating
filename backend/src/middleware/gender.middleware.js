const AppError = require('../utils/AppError');

const requireGender = (gender) => {
  return (req, res, next) => {
    if (req.user.gender !== gender) {
      return next(
        new AppError(`This action is only available for ${gender} users`, 403)
      );
    }
    next();
  };
};

module.exports = requireGender;
