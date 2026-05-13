const swipeService = require('../services/swipe.service');
const catchAsync = require('../utils/catchAsync');

const getFeed = catchAsync(async (req, res) => {
  const result = await swipeService.getFeed(
    req.user.id,
    req.cleanQuery.cursor,
    parseInt(req.cleanQuery.limit, 10) || 20,
    {
      minAge: req.cleanQuery.minAge ? parseInt(req.cleanQuery.minAge, 10) : undefined,
      maxAge: req.cleanQuery.maxAge ? parseInt(req.cleanQuery.maxAge, 10) : undefined,
      maxDistanceKm: req.cleanQuery.maxDistanceKm
        ? parseInt(req.cleanQuery.maxDistanceKm, 10)
        : undefined,
      intent: req.cleanQuery.intent,
    },
  );
  res.status(200).json(result);
});

const like = catchAsync(async (req, res) => {
  await swipeService.like(req.user.id, req.body.userId);

  // Spec §12: emit `new-like` to the boy's personal room.
  // Payload shape: `{ fromUserId: string }`.
  const io = req.app.get('io');
  if (io) {
    io.to(req.body.userId).emit('new-like', {
      fromUserId: req.user.id.toString(),
    });
  }

  // Spec §3: response is `{}` (200).
  res.status(200).json({});
});

const skip = catchAsync(async (req, res) => {
  await swipeService.skip(req.user.id, req.body.userId);
  res.status(200).json({});
});

const undoLastSkip = catchAsync(async (req, res) => {
  const result = await swipeService.undoLastSkip(req.user.id);
  // Spec §3: response shape is `{ undoneUserId: string }`.
  res.status(200).json({ undoneUserId: result.undoneUserId });
});

module.exports = {
  getFeed, like, skip, undoLastSkip,
};
