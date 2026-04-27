const matchService = require('../services/match.service');
const catchAsync = require('../utils/catchAsync');

const getMatches = catchAsync(async (req, res) => {
  const { cursor, limit } = req.query;
  const result = await matchService.getMatches(
    req.user.id,
    cursor || null,
    parseInt(limit, 10) || 20,
  );
  res.status(200).json(result);
});

const deleteMatch = catchAsync(async (req, res) => {
  const result = await matchService.deleteMatch(req.params.matchId, req.user.id);
  res.status(200).json(result);
});

module.exports = { getMatches, deleteMatch };
