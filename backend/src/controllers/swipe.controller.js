const swipeService = require('../services/swipe.service');
const catchAsync = require('../utils/catchAsync');

const getFeed = catchAsync(async (req, res) => {
  const { cursor, limit } = req.query;
  const result = await swipeService.getFeed(
    req.user.id,
    cursor,
    parseInt(limit) || 20
  );
  res.status(200).json(result);
});

const like = catchAsync(async (req, res) => {
  const result = await swipeService.like(req.user.id, req.body.userId);

  // Emit socket event to the boy if online
  const io = req.app.get('io');
  if (io) {
    io.to(req.body.userId).emit('new-like', {
      message: 'Someone liked your profile',
    });
  }

  res.status(201).json(result);
});

const skip = catchAsync(async (req, res) => {
  const result = await swipeService.skip(req.user.id, req.body.userId);
  res.status(200).json(result);
});

const undoLastSkip = catchAsync(async (req, res) => {
  const result = await swipeService.undoLastSkip(req.user.id);
  res.status(200).json(result);
});

module.exports = { getFeed, like, skip, undoLastSkip };
