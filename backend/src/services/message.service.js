const Message = require('../models/Message');
const Match = require('../models/Match');
const AppError = require('../utils/AppError');
const { sendPush } = require('./notification.service');

/**
 * Get messages for a match using cursor-based pagination.
 * cursor is the last seen message _id; returns older messages.
 */
const getMessages = async (matchId, userId, cursor, limit = 30) => {
  const match = await Match.findById(matchId);
  if (!match) throw new AppError('Match not found', 404);

  if (!match.users.some((u) => u.toString() === userId.toString())) {
    throw new AppError('Unauthorized', 403);
  }

  const filter = { matchId };
  if (cursor) {
    filter._id = { $lt: cursor };
  }

  const messages = await Message.find(filter)
    .sort({ _id: -1 })
    .limit(limit + 1)
    .select('sender text seen seenAt createdAt');

  const hasMore = messages.length > limit;
  if (hasMore) messages.pop();

  const nextCursor = hasMore ? messages[messages.length - 1]._id.toString() : null;

  return {
    messages: messages.reverse(),
    nextCursor,
    hasMore,
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
    { seen: true, seenAt: new Date() }
  );
};

module.exports = { getMessages, sendMessage, markSeen };
