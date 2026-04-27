const messageService = require('../services/message.service');
const catchAsync = require('../utils/catchAsync');

const getMessages = catchAsync(async (req, res) => {
  const { cursor, limit } = req.query;
  const result = await messageService.getMessages(
    req.params.matchId,
    req.user.id,
    cursor || null,
    parseInt(limit, 10) || 30
  );
  res.status(200).json(result);
});

const sendMessage = catchAsync(async (req, res) => {
  const message = await messageService.sendMessage(
    req.body.matchId,
    req.user.id,
    req.body.text
  );

  const io = req.app.get('io');
  if (io) {
    io.to(req.body.matchId).emit('new-message', message);
  }

  res.status(200).json(message);
});

const markSeen = catchAsync(async (req, res) => {
  await messageService.markSeen(req.params.matchId, req.user.id);
  res.status(200).json({ message: 'Messages marked as seen' });
});

module.exports = { getMessages, sendMessage, markSeen };
