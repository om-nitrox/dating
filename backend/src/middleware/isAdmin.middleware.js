const User = require('../models/User');
const AppError = require('../utils/AppError');

const isAdmin = async (req, res, next) => {
  const user = await User.findById(req.user.id).select('role banned');

  if (!user) return next(new AppError('User not found', 404));
  if (user.banned) return next(new AppError('Your account has been suspended', 403));
  if (user.role !== 'admin') return next(new AppError('Admin access required', 403));

  next();
};

module.exports = isAdmin;
