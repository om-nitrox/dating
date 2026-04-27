const mongoose = require('mongoose');
const User = require('../models/User');
const Report = require('../models/Report');
const Match = require('../models/Match');
const Message = require('../models/Message');
const Like = require('../models/Like');
const Block = require('../models/Block');
const { getRedis } = require('../config/redis');
const { sendPush } = require('./notification.service');
const AppError = require('../utils/AppError');
const logger = require('../utils/logger');

/**
 * List reports with reporter and reported user details populated.
 * Supports filtering by status and cursor-based pagination.
 */
const listReports = async (status = 'pending', cursor, limit = 20) => {
  const filter = {};
  if (status !== 'all') filter.status = status;
  if (cursor) filter._id = { $lt: new mongoose.Types.ObjectId(cursor) };

  const reports = await Report.find(filter)
    .sort({ _id: -1 })
    .limit(limit + 1)
    .populate('reporter', 'name email')
    .populate('reported', 'name email banned')
    .populate('resolvedBy', 'name email');

  const hasMore = reports.length > limit;
  if (hasMore) reports.pop();

  return {
    reports,
    nextCursor: hasMore ? reports[reports.length - 1]._id.toString() : null,
    hasMore,
  };
};

/**
 * Mark a report as resolved (or dismissed). Optionally ban the reported user.
 */
const resolveReport = async (reportId, adminId, banUser = false) => {
  const report = await Report.findById(reportId);
  if (!report) throw new AppError('Report not found', 404);

  report.status = 'resolved';
  report.resolvedAt = new Date();
  report.resolvedBy = adminId;
  await report.save();

  if (banUser) {
    await banUserById(report.reported.toString(), adminId);
  }

  return { message: 'Report resolved', report };
};

/**
 * Ban a user: set banned=true, revoke all tokens, clear FCM tokens, send push notification.
 */
const banUserById = async (targetUserId, adminId) => {
  const user = await User.findById(targetUserId);
  if (!user) throw new AppError('User not found', 404);
  if (user.role === 'admin') throw new AppError('Cannot ban another admin', 403);

  // Revoke refresh token
  user.banned = true;
  user.refreshToken = null;
  user.fcmTokens = [];
  await user.save();

  // Note: existing access tokens will still be valid until their natural expiry.
  // The auth middleware checks user.banned on each request to catch this case.
  // For immediate revocation, maintain a banned-users set in Redis.
  try {
    const redis = getRedis();
    await redis.set(`banned:${targetUserId}`, '1');
  } catch (_) {}

  sendPush(targetUserId, 'Account Suspended', 'Your Reverse Match account has been suspended for violating community guidelines.', {
    type: 'account_banned',
  });

  logger.info({ targetUserId, adminId }, 'User banned by admin');

  return { message: 'User banned', userId: targetUserId };
};

/**
 * Get full user profile for admin review.
 */
const getAdminUserProfile = async (userId) => {
  const user = await User.findById(userId).select('-refreshToken -__v');
  if (!user) throw new AppError('User not found', 404);

  const [matchCount, reportCount] = await Promise.all([
    Match.countDocuments({ users: userId }),
    Report.countDocuments({ reported: userId }),
  ]);

  return {
    user,
    stats: { matchCount, reportCount },
  };
};

module.exports = { listReports, resolveReport, banUserById, getAdminUserProfile };
