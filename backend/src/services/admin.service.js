const mongoose = require('mongoose');
const User = require('../models/User');
const Report = require('../models/Report');
const Match = require('../models/Match');
const config = require('../config');
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
    // Always set with a TTL — without it a banned-flag could linger forever
    // even after the underlying user is reinstated or deleted.  The TTL is
    // sized to outlive any in-flight access token.
    await redis.set(
      `banned:${targetUserId}`,
      '1',
      'EX',
      config.jwtAccessExpirySeconds,
    );
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

/**
 * Phase 1.3 — Admin selfie review queue.
 *
 * `listPendingSelfies` returns users with `selfieReviewStatus === 'pending'`,
 * page-paginated (consistent with /matches and /queue pagination style).
 *
 * `approveSelfie` flips `isVerified = true` and `selfieReviewStatus =
 * 'approved'`. This is the canonical gate for the "verified" badge.
 *
 * `rejectSelfie` flips `selfieReviewStatus = 'rejected'` and (best-effort)
 * pushes an FCM notification to the user explaining the next step.
 */
const listPendingSelfies = async (page = 1, limit = 20) => {
  const safeLimit = Math.min(Math.max(limit, 1), 100);
  const skip = (page - 1) * safeLimit;

  const filter = { selfieReviewStatus: 'pending' };

  const [users, total] = await Promise.all([
    User.find(filter)
      .sort({ updatedAt: -1 })
      .skip(skip)
      .limit(safeLimit)
      .select('_id name email photos selfiePhoto isVerified selfieReviewStatus updatedAt'),
    User.countDocuments(filter),
  ]);

  return {
    users,
    page,
    limit: safeLimit,
    total,
    hasMore: skip + users.length < total,
  };
};

const approveSelfie = async (targetUserId, adminId) => {
  const user = await User.findById(targetUserId);
  if (!user) throw new AppError('User not found', 404);

  if (user.selfieReviewStatus !== 'pending') {
    throw new AppError(
      `Selfie is not pending review (current state: ${user.selfieReviewStatus || 'none'})`,
      400,
      'NOT_PENDING_REVIEW',
    );
  }

  user.isVerified = true;
  user.selfieReviewStatus = 'approved';
  await user.save();

  logger.info(
    {
      event: 'admin.selfie.approved',
      targetUserId: String(targetUserId),
      adminId: String(adminId),
    },
    'selfie approved by admin',
  );

  // Best-effort FCM heads-up to the user.
  try {
    sendPush(
      targetUserId,
      'You are verified!',
      'Your selfie was approved. You now have the verified badge on your profile.',
      { type: 'selfie_approved' },
    );
  } catch (_) { /* noop */ }

  return { userId: String(targetUserId), isVerified: true, selfieReviewStatus: 'approved' };
};

const rejectSelfie = async (targetUserId, adminId, reason) => {
  const user = await User.findById(targetUserId);
  if (!user) throw new AppError('User not found', 404);

  if (user.selfieReviewStatus !== 'pending') {
    throw new AppError(
      `Selfie is not pending review (current state: ${user.selfieReviewStatus || 'none'})`,
      400,
      'NOT_PENDING_REVIEW',
    );
  }

  user.selfieReviewStatus = 'rejected';
  user.isVerified = false;
  await user.save();

  logger.info(
    {
      event: 'admin.selfie.rejected',
      targetUserId: String(targetUserId),
      adminId: String(adminId),
      reason: reason ? String(reason).slice(0, 200) : null,
    },
    'selfie rejected by admin',
  );

  try {
    sendPush(
      targetUserId,
      'Selfie verification rejected',
      reason
        ? `Please re-upload your selfie. Reason: ${String(reason).slice(0, 120)}`
        : 'Please re-upload your selfie to get verified.',
      { type: 'selfie_rejected' },
    );
  } catch (_) { /* noop */ }

  return { userId: String(targetUserId), selfieReviewStatus: 'rejected' };
};

module.exports = {
  listReports,
  resolveReport,
  banUserById,
  getAdminUserProfile,
  // Phase 1.3 — selfie review queue
  listPendingSelfies,
  approveSelfie,
  rejectSelfie,
};
