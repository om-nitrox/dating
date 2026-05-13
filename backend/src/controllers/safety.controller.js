const safetyService = require('../services/safety.service');
const catchAsync = require('../utils/catchAsync');

const reportUser = catchAsync(async (req, res) => {
  await safetyService.reportUser(
    req.user.id,
    req.body.userId,
    req.body.reason,
    req.body.details,
  );
  // Spec §8: response is empty object (200).
  res.status(200).json({});
});

const blockUser = catchAsync(async (req, res) => {
  await safetyService.blockUser(req.user.id, req.body.userId);
  // Spec §8: response is empty object (200).
  res.status(200).json({});
});

module.exports = { reportUser, blockUser };
