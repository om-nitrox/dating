const mongoose = require('mongoose');
const Match = require('../models/Match');
const AppError = require('../utils/AppError');

/**
 * Get all matches for a user with last message and unread count.
 * Uses a single aggregation pipeline instead of N+1 queries.
 */
const getMatches = async (userId, page = 1, limit = 30) => {
  const objectUserId = new mongoose.Types.ObjectId(userId);
  const skip = (page - 1) * limit;

  const matches = await Match.aggregate([
    // Find matches where this user is a participant
    { $match: { users: objectUserId } },

    // Lookup the last message for each match
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

    // Lookup unread count for this user
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

    // Populate users
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

    // Reshape
    {
      $addFields: {
        lastMessage: { $arrayElemAt: ['$lastMessageArr', 0] },
        unreadCount: {
          $ifNull: [{ $arrayElemAt: ['$unreadArr.count', 0] }, 0],
        },
        // Sort key: last message time or match creation time
        sortTime: {
          $ifNull: [
            { $arrayElemAt: ['$lastMessageArr.createdAt', 0] },
            '$createdAt',
          ],
        },
      },
    },

    // Clean up temporary fields
    { $project: { lastMessageArr: 0, unreadArr: 0 } },

    // Sort by most recent activity
    { $sort: { sortTime: -1 } },

    // Paginate
    { $skip: skip },
    { $limit: limit },
  ]);

  const total = await Match.countDocuments({ users: objectUserId });

  return {
    matches,
    page,
    totalPages: Math.ceil(total / limit),
    hasMore: skip + limit < total,
  };
};

/**
 * Delete/unmatch a match. Removes the match and all associated messages.
 */
const deleteMatch = async (matchId, userId) => {
  const objectUserId = new mongoose.Types.ObjectId(userId);
  const match = await Match.findById(matchId);

  if (!match) throw new AppError('Match not found', 404);
  if (!match.users.some((u) => u.toString() === userId)) {
    throw new AppError('Unauthorized', 403);
  }

  const Message = require('../models/Message');

  // Delete all messages in this match
  await Message.deleteMany({ matchId: match._id });
  // Delete the match itself
  await Match.findByIdAndDelete(matchId);

  return { message: 'Unmatched successfully' };
};

module.exports = { getMatches, deleteMatch };
