const queueService = require('../services/queue.service');
const catchAsync = require('../utils/catchAsync');
const { emitNewMatch } = require('../realtime/events');

const getQueue = catchAsync(async (req, res) => {
  // Spec §4 (Phase 0.3): page-paginated, `?page=&limit=`. Read from
  // req.cleanQuery (Express 5 — req.query is read-only after sanitize).
  // The zodValidate middleware will have already coerced numeric strings
  // to numbers, but be defensive in case a route bypasses validation.
  const page = parseInt(req.cleanQuery.page, 10) || 1;
  const limit = parseInt(req.cleanQuery.limit, 10) || 20;
  const result = await queueService.getQueue(req.user.id, page, limit);
  res.status(200).json(result);
});

const accept = catchAsync(async (req, res) => {
  const match = await queueService.accept(req.user.id, req.params.likeId);

  // Phase 0.6: route the new-match emit through the centralized event bus.
  emitNewMatch(req.app.get('io'), { match, log: req.log });

  res.status(200).json({ match });
});

const reject = catchAsync(async (req, res) => {
  const result = await queueService.reject(req.user.id, req.params.likeId);
  res.status(200).json(result);
});

module.exports = { getQueue, accept, reject };
