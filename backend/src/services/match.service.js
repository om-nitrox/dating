const mongoose = require('mongoose');
const Match = require('../models/Match');
const Message = require('../models/Message');
const AppError = require('../utils/AppError');
const { USER_PROJECTION } = require('../utils/userProjection');
const withTransaction = require('../utils/withTransaction');

/**
 * Get all matches for a user with last message and unread count.
 * Spec §5: page-based pagination, sort by lastMessage.createdAt DESC.
 */
const getMatches = async (userId, page = 1, limit = 20) => {
  const objectUserId = new mongoose.Types.ObjectId(userId);
  const safePage = Math.max(1, parseInt(page, 10) || 1);
  const safeLimit = Math.min(50, Math.max(1, parseInt(limit, 10) || 20));
  const skip = (safePage - 1) * safeLimit;

  const matches = await Match.aggregate([
    { $match: { users: objectUserId } },

    // Last message
    {
      $lookup: {
        from: 'messages',
        let: { matchId: '$_id' },
        pipeline: [
          { $match: { $expr: { $eq: ['$matchId', '$$matchId'] } } },
          { $sort: { createdAt: -1 } },
          { $limit: 1 },
          {
            $project: {
              _id: 1,
              matchId: 1,
              text: 1,
              sender: 1,
              seen: 1,
              createdAt: 1,
            },
          },
        ],
        as: 'lastMessageArr',
      },
    },

    // Unread count (messages sent by the OTHER user that are still unseen)
    {
      $lookup: {
        from: 'messages',
        let: { matchId: '$_id' },
        pipeline: [
          {
            $match: {
              $expr: {
                $and: [
                  { $eq: ['$matchId', '$$matchId'] },
                  { $ne: ['$sender', objectUserId] },
                  { $eq: ['$seen', false] },
                ],
              },
            },
          },
          { $count: 'count' },
        ],
        as: 'unreadArr',
      },
    },

    // Populate both users with the full UserModel-compatible projection
    {
      $lookup: {
        from: 'users',
        localField: 'users',
        foreignField: '_id',
        pipeline: [{ $project: USER_PROJECTION }],
        as: 'users',
      },
    },

    {
      $addFields: {
        lastMessage: { $arrayElemAt: ['$lastMessageArr', 0] },
        unreadCount: { $ifNull: [{ $arrayElemAt: ['$unreadArr.count', 0] }, 0] },
        // Sort key: last message createdAt, falling back to match createdAt
        // so brand-new matches (with no messages) still get a deterministic
        // position at the top of the list.
        sortKey: {
          $ifNull: [{ $arrayElemAt: ['$lastMessageArr.createdAt', 0] }, '$createdAt'],
        },
      },
    },

    { $sort: { sortKey: -1, _id: -1 } },
    { $skip: skip },
    { $limit: safeLimit + 1 }, // peek at one extra row to compute hasMore

    { $project: { lastMessageArr: 0, unreadArr: 0, sortKey: 0 } },
  ]);

  const hasMore = matches.length > safeLimit;
  if (hasMore) matches.pop();

  // Spec: `lastMessage` is `null` when there are no messages yet.
  matches.forEach((m) => {
    if (!m.lastMessage) m.lastMessage = null;
  });

  return { matches, hasMore };
};

/**
 * Delete/unmatch a match. Removes the match and all associated messages.
 *
 * Cascading delete runs in a transaction when supported so a failure
 * between the two deleteMany calls can't leave orphan messages.
 */
const deleteMatch = async (matchId, userId) => {
  const match = await Match.findById(matchId);

  if (!match) throw new AppError('Match not found', 404);
  if (!match.users.some((u) => u.toString() === userId)) {
    throw new AppError('Unauthorized', 403);
  }

  await withTransaction(async (session) => {
    const opts = session ? { session } : {};
    await Message.deleteMany({ matchId: match._id }, opts);
    await Match.deleteOne({ _id: matchId }, opts);
  });

  return { match };
};

module.exports = { getMatches, deleteMatch };
