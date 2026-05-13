const idealMatchService = require('../services/idealMatch.service');
const catchAsync = require('../utils/catchAsync');

const getIdealMatch = catchAsync(async (req, res) => {
  const limit = Math.min(20, Math.max(1, parseInt(req.cleanQuery.limit, 10) || 5));
  const result = await idealMatchService.getIdealMatch(req.user.id, limit);
  res.status(200).json(result);
});

module.exports = { getIdealMatch };
