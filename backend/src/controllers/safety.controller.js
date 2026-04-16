const safetyService = require('../services/safety.service');
const catchAsync = require('../utils/catchAsync');

const reportUser = catchAsync(async (req, res) => {
  const result = await safetyService.reportUser(
    req.user.id,
    req.body.userId,
    req.body.reason,
    req.body.details
  );
  res.status(201).json(result);
});

const blockUser = catchAsync(async (req, res) => {
  const result = await safetyService.blockUser(req.user.id, req.body.userId);
  res.status(200).json(result);
});

module.exports = { reportUser, blockUser };
