const Message = require('../models/Message');
const Match = require('../models/Match');
const AppError = require('../utils/AppError');
const { sendPush } = require('./notification.service');

const MAX_PAGE_LIMIT = 100;

/**
 * Get messages for a match using page-based pagination (spec §6).
 * Page 1 = the most recent `limit` messages. Newest at the end of the
 * returned array (chronological order — frontend renders bottom-to-top).
 */
const getMessages = async (matchId, userId, page = 1, limit = 50) => {
  const match = await Match.findById(matchId);
  if (!match) throw new AppError('Match not found', 404);

  if (!match.users.some((u) => u.toString() === userId.toString())) {
    throw new AppError('Unauthorized', 403);
  }

  const safePage = Math.max(1, parseInt(page, 10) || 1);
  const safeLimit = Math.min(MAX_PAGE_LIMIT, Math.max(1, parseInt(limit, 10) || 50));
  const skip = (safePage - 1) * safeLimit;

  // Fetch newest-first by createdAt, then reverse for chronological order.
  // Pull one extra row to determine `hasMore` without a count query.
  const docs = await Message.find({ matchId })
    .sort({ createdAt: -1, _id: -1 })
    .skip(skip)
    .limit(safeLimit + 1)
    .select('matchId sender text seen seenAt createdAt');

  const hasMore = docs.length > safeLimit;
  if (hasMore) docs.pop();

  // Chronological order: oldest of this page first, newest last.
  const messages = docs.reverse();

  return { messages, hasMore };
};

/**
 * Send a message in a match. Returns both the saved message and the match
 * doc so callers (REST controller + socket handler) can avoid a second
 * Match.findById round trip when fan-out broadcasting.
 */
const sendMessage = async (matchId, senderId, text) => {
  const match = await Match.findById(matchId).select('users');
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
    (u) => u.toString() !== senderId.toString(),
  );

  if (recipientId) {
    sendPush(recipientId, 'New Message', text.substring(0, 100), {
      type: 'new_message',
      matchId: matchId.toString(),
    });
  }

  return { message, match };
};

const markSeen = async (matchId, userId) => {
  // Ownership check — only participants of the match may mark messages seen.
  // Mirrors the pattern in getMessages / sendMessage.
  const match = await Match.findById(matchId).select('users');
  if (!match) throw new AppError('Match not found', 404);
  if (!match.users.some((u) => u.toString() === userId.toString())) {
    throw new AppError('Unauthorized', 403);
  }

  const now = new Date();
  await Message.updateMany(
    {
      matchId,
      sender: { $ne: userId },
      seen: false,
    },
    { seen: true, seenAt: now },
  );
  return now;
};

module.exports = { getMessages, sendMessage, markSeen };
