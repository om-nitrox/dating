const Report = require('../models/Report');
const Block = require('../models/Block');
const Match = require('../models/Match');
const Like = require('../models/Like');
const AppError = require('../utils/AppError');

const reportUser = async (reporterId, reportedId, reason, details) => {
  if (reporterId.toString() === reportedId) {
    throw new AppError('Cannot report yourself', 400);
  }

  await Report.create({
    reporter: reporterId,
    reported: reportedId,
    reason,
    details,
  });

  return { message: 'Report submitted' };
};

const blockUser = async (blockerId, blockedId) => {
  if (blockerId.toString() === blockedId) {
    throw new AppError('Cannot block yourself', 400);
  }

  try {
    await Block.create({ blocker: blockerId, blocked: blockedId });
  } catch (err) {
    if (err.code === 11000) {
      throw new AppError('User already blocked', 409);
    }
    throw err;
  }

  // Remove any existing match between the two
  await Match.deleteMany({
    users: { $all: [blockerId, blockedId] },
  });

  // Remove pending likes
  await Like.deleteMany({
    $or: [
      { fromUser: blockerId, toUser: blockedId },
      { fromUser: blockedId, toUser: blockerId },
    ],
  });

  return { message: 'User blocked' };
};

module.exports = { reportUser, blockUser };
