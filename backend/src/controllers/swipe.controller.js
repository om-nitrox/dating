const swipeService = require('../services/swipe.service');
const catchAsync = require('../utils/catchAsync');
const { emitNewLike } = require('../realtime/events');

const getFeed = catchAsync(async (req, res) => {
  const result = await swipeService.getFeed(
    req.user.id,
    req.cleanQuery.cursor,
    parseInt(req.cleanQuery.limit, 10) || 20,
    {
      minAge: req.cleanQuery.minAge ? parseInt(req.cleanQuery.minAge, 10) : undefined,
      maxAge: req.cleanQuery.maxAge ? parseInt(req.cleanQuery.maxAge, 10) : undefined,
      minHeight: req.cleanQuery.minHeight
        ? parseInt(req.cleanQuery.minHeight, 10)
        : undefined,
      maxHeight: req.cleanQuery.maxHeight
        ? parseInt(req.cleanQuery.maxHeight, 10)
        : undefined,
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

  // Phase 0.6: emit `new-like` through the centralized event bus.
  emitNewLike(req.app.get('io'), {
    fromUserId: req.user.id,
    toUserId: req.body.userId,
    log: req.log,
  });

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
