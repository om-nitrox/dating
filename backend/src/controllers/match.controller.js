const matchService = require('../services/match.service');
const Match = require('../models/Match');
const catchAsync = require('../utils/catchAsync');

const getMatches = catchAsync(async (req, res) => {
  // Spec §5: page-based pagination — `?page=1&limit=20`.
  const page = parseInt(req.cleanQuery.page, 10) || 1;
  const limit = parseInt(req.cleanQuery.limit, 10) || 20;
  const result = await matchService.getMatches(req.user.id, page, limit);
  res.status(200).json(result);
});

const deleteMatch = catchAsync(async (req, res) => {
  // Look up the match first so we can emit to the other user before deletion.
  const existing = await Match.findById(req.params.matchId).select('users').lean();
  await matchService.deleteMatch(req.params.matchId, req.user.id);

  // Optional `match-deleted` emit (spec §5)
  if (existing) {
    const io = req.app.get('io');
    if (io) {
      existing.users.forEach((u) => {
        const uid = u.toString();
        if (uid !== req.user.id.toString()) {
          io.to(uid).emit('match-deleted', { matchId: req.params.matchId });
        }
      });
    }
  }

  // Spec §5: response is empty object.
  res.status(200).json({});
});

module.exports = { getMatches, deleteMatch };
