const matchService = require('../services/match.service');
const Match = require('../models/Match');
const catchAsync = require('../utils/catchAsync');
const { emitMatchDeleted } = require('../realtime/events');

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

  // Phase 0.6: emit `match-deleted` via the centralized event bus.
  if (existing) {
    emitMatchDeleted(req.app.get('io'), {
      matchId: req.params.matchId,
      participantIds: existing.users,
      actorId: req.user.id,
    });
  }

  // Spec §5: response is empty object.
  res.status(200).json({});
});

module.exports = { getMatches, deleteMatch };
