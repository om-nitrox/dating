const mongoose = require('mongoose');
const Match = require('../models/Match');
const AppError = require('../utils/AppError');

/**
 * Get all matches for a user with last message and unread count.
 * Uses cursor-based pagination — cursor is the last seen match _id.
 */
const getMatches = async (userId, cursor, limit = 20) => {
  const objectUserId = new mongoose.Types.ObjectId(userId);

  const matchFilter = { users: objectUserId };
  if (cursor) {
    matchFilter._id = { $lt: new mongoose.Types.ObjectId(cursor) };
  }

  const matches = await Match.aggregate([
    { $match: matchFilter },
    { $sort: { _id: -1 } },
    { $limit: limit + 1 },

    {
      $lookup: {
        from: 'messages',
        let: { matchId: '$_id' },
        pipeline: [
          { $match: { $expr: { $eq: ['$matchId', '$$matchId'] } } },
          { $sort: { createdAt: -1 } },
          { $limit: 1 },
          { $project: { text: 1, sender: 1, seen: 1, createdAt: 1 } },
        ],
        as: 'lastMessageArr',
      },
    },

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

    {
      $lookup: {
        from: 'users',
        localField: 'users',
        foreignField: '_id',
        pipeline: [
          { $project: { name: 1, age: 1, photos: 1, bio: 1 } },
        ],
        as: 'users',
      },
    },

    {
      $addFields: {
        lastMessage: { $arrayElemAt: ['$lastMessageArr', 0] },
        unreadCount: {
          $ifNull: [{ $arrayElemAt: ['$unreadArr.count', 0] }, 0],
        },
      },
    },

    { $project: { lastMessageArr: 0, unreadArr: 0 } },
  ]);

  const hasMore = matches.length > limit;
  if (hasMore) matches.pop();

  const nextCursor = hasMore ? matches[matches.length - 1]._id.toString() : null;

  return { matches, nextCursor, hasMore };
};

/**
 * Delete/unmatch a match. Removes the match and all associated messages.
 */
const deleteMatch = async (matchId, userId) => {
  const match = await Match.findById(matchId);

  if (!match) throw new AppError('Match not found', 404);
  if (!match.users.some((u) => u.toString() === userId)) {
    throw new AppError('Unauthorized', 403);
  }

  const Message = require('../models/Message');

  await Message.deleteMany({ matchId: match._id });
  await Match.findByIdAndDelete(matchId);

  return { message: 'Unmatched successfully' };
};

module.exports = { getMatches, deleteMatch };
