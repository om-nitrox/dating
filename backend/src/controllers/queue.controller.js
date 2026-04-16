const queueService = require('../services/queue.service');
const catchAsync = require('../utils/catchAsync');

const getQueue = catchAsync(async (req, res) => {
  const { page, limit } = req.query;
  const result = await queueService.getQueue(
    req.user.id,
    parseInt(page) || 1,
    parseInt(limit) || 20
  );
  res.status(200).json(result);
});

const accept = catchAsync(async (req, res) => {
  const match = await queueService.accept(req.user.id, req.params.likeId);

  // Emit socket event to both users
  const io = req.app.get('io');
  if (io) {
    match.users.forEach((user) => {
      io.to(user._id.toString()).emit('new-match', {
        match,
      });
    });
  }

  res.status(200).json({ match });
});

const reject = catchAsync(async (req, res) => {
  const result = await queueService.reject(req.user.id, req.params.likeId);
  res.status(200).json(result);
});

module.exports = { getQueue, accept, reject };
