const Message = require('../models/Message');
const Match = require('../models/Match');
const AppError = require('../utils/AppError');
const { sendPush } = require('./notification.service');

const getMessages = async (matchId, userId, page = 1, limit = 50) => {
  // Verify user is a participant
  const match = await Match.findById(matchId);
  if (!match) throw new AppError('Match not found', 404);

  if (!match.users.some((u) => u.toString() === userId.toString())) {
    throw new AppError('Unauthorized', 403);
  }

  const skip = (page - 1) * limit;

  const messages = await Message.find({ matchId })
    .sort({ createdAt: -1 })
    .skip(skip)
    .limit(limit)
    .select('sender text seen createdAt');

  const total = await Message.countDocuments({ matchId });

  return {
    messages: messages.reverse(), // Return oldest-first for display
    page,
    totalPages: Math.ceil(total / limit),
    hasMore: skip + limit < total,
  };
};

const sendMessage = async (matchId, senderId, text) => {
  const match = await Match.findById(matchId);
  if (!match) throw new AppError('Match not found', 404);

  if (!match.users.some((u) => u.toString() === senderId.toString())) {
    throw new AppError('Unauthorized', 403);
  }

  const message = await Message.create({
    matchId,
    sender: senderId,
    text,
  });

  // Find the other user and send push if offline
  const recipientId = match.users.find(
    (u) => u.toString() !== senderId.toString()
  );

  sendPush(recipientId, 'New Message', text.substring(0, 100), {
    type: 'new_message',
    matchId: matchId.toString(),
  });

  return message;
};

const markSeen = async (matchId, userId) => {
  await Message.updateMany(
    {
      matchId,
      sender: { $ne: userId },
      seen: false,
    },
    { seen: true }
  );
};

module.exports = { getMessages, sendMessage, markSeen };
