const messageService = require('../services/message.service');
const catchAsync = require('../utils/catchAsync');
const { emitNewMessage, emitMessagesSeen } = require('../realtime/events');

const getMessages = catchAsync(async (req, res) => {
  // Spec §6: page-based, defaults page=1, limit=50.
  const page = parseInt(req.cleanQuery.page, 10) || 1;
  const limit = parseInt(req.cleanQuery.limit, 10) || 50;
  const result = await messageService.getMessages(
    req.params.matchId,
    req.user.id,
    page,
    limit,
  );
  res.status(200).json(result);
});

const sendMessage = catchAsync(async (req, res) => {
  // Service returns { message, match } so we don't have to refetch the
  // Match doc to fan-out broadcast (fix 28).
  const { message, match } = await messageService.sendMessage(
    req.body.matchId,
    req.user.id,
    req.body.text,
  );

  // Phase 0.6: emit `new-message` through the centralized event bus.
  emitNewMessage(req.app.get('io'), {
    matchId: req.body.matchId,
    message,
    participantIds: match ? match.users : [],
    log: req.log,
  });

  // Spec §6: response is the FLAT MessageModel (NOT wrapped in `{ message }`).
  res.status(200).json(message);
});

const markSeen = catchAsync(async (req, res) => {
  const seenAt = await messageService.markSeen(req.params.matchId, req.user.id);

  // Phase 0.6: emit `messages-seen` through the centralized event bus.
  // markSeen already verified participation. We do one targeted Match read
  // here so we can route to the OTHER user's personal room.
  const io = req.app.get('io');
  if (io) {
    // eslint-disable-next-line global-require
    const Match = require('../models/Match');
    const match = await Match.findById(req.params.matchId).select('users').lean();
    if (match) {
      const otherId = match.users.find(
        (u) => u.toString() !== req.user.id.toString(),
      );
      if (otherId) {
        emitMessagesSeen(io, {
          matchId: req.params.matchId,
          otherUserId: otherId,
          seenAt: seenAt.toISOString(),
          log: req.log,
        });
      }
    }
  }

  res.status(200).json({});
});

module.exports = { getMessages, sendMessage, markSeen };
