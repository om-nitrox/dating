const queueService = require('../services/queue.service');
const catchAsync = require('../utils/catchAsync');

const getQueue = catchAsync(async (req, res) => {
  // Spec §4: no pagination — return the full pending queue.
  const result = await queueService.getQueue(req.user.id);
  res.status(200).json(result);
});

const accept = catchAsync(async (req, res) => {
  const match = await queueService.accept(req.user.id, req.params.likeId);

  // Spec §4 + §12: emit `new-match` to BOTH users so the girl's app picks it up.
  // Payload shape: `{ match: MatchModel }` (spec §12).
  const io = req.app.get('io');
  if (io) {
    match.users.forEach((u) => {
      io.to(u._id.toString()).emit('new-match', { match });
    });
  }

  res.status(200).json({ match });
});

const reject = catchAsync(async (req, res) => {
  const result = await queueService.reject(req.user.id, req.params.likeId);
  res.status(200).json(result);
});

module.exports = { getQueue, accept, reject };
