const idealMatchService = require('../services/idealMatch.service');
const catchAsync = require('../utils/catchAsync');

const getIdealMatch = catchAsync(async (req, res) => {
  const limit = Math.min(20, Math.max(1, parseInt(req.cleanQuery.limit, 10) || 5));
  const result = await idealMatchService.getIdealMatch(req.user.id, limit);
  res.status(200).json(result);
});

// GET /ideal-match/status — eligibility snapshot for the button (no use spent)
const getStatus = catchAsync(async (req, res) => {
  const result = await idealMatchService.getIdealMatchStatus(req.user.id);
  res.status(200).json(result);
});

// POST /ideal-match/reveal — run ML, return the 1 ideal match, spend a use
const reveal = catchAsync(async (req, res) => {
  const result = await idealMatchService.revealIdealMatch(req.user.id);
  res.status(200).json(result);
});

module.exports = { getIdealMatch, getStatus, reveal };
