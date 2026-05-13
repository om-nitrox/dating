const Report = require('../models/Report');
const Block = require('../models/Block');
const Match = require('../models/Match');
const Message = require('../models/Message');
const Like = require('../models/Like');
const config = require('../config');
const AppError = require('../utils/AppError');
const logger = require('../utils/logger');
const withTransaction = require('../utils/withTransaction');

const sessionOpt = (session) => (session ? { session } : {});

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

  // Auto-suspend after N pending reports against the same user. Threshold is
  // configurable via REPORT_AUTO_SUSPEND_THRESHOLD (default 5). We do NOT
  // count resolved/dismissed reports — only pending ones.
  try {
    const pendingCount = await Report.countDocuments({
      reported: reportedId,
      status: 'pending',
    });
    if (pendingCount >= config.reportAutoSuspendThreshold) {
      // Lazy require to avoid circular admin.service <-> safety.service issues.
      // (admin.service doesn't import safety.service currently, but be safe.)
      // eslint-disable-next-line global-require
      const adminService = require('./admin.service');
      try {
        await adminService.banUserById(
          reportedId.toString(),
          null, // system actor — no admin id
        );
        logger.info({ reportedId, pendingCount }, 'Auto-suspended user after report threshold');
      } catch (banErr) {
        // Bans can fail benignly (e.g., user already admin or already deleted).
        logger.warn({ err: banErr.message, reportedId }, 'Auto-suspend banUser failed');
      }
    }
  } catch (err) {
    logger.warn({ err: err.message }, 'Report auto-suspend check failed');
  }

  return { message: 'Report submitted' };
};

const blockUser = async (blockerId, blockedId) => {
  if (blockerId.toString() === blockedId) {
    throw new AppError('Cannot block yourself', 400);
  }

  // Pre-create the block outside the transaction so we get the 11000 duplicate
  // error and can return 409 cleanly. If this succeeds, run the cascading
  // deletes (Match + child Messages + symmetric Likes) atomically.
  try {
    await Block.create({ blocker: blockerId, blocked: blockedId });
  } catch (err) {
    if (err.code === 11000) {
      throw new AppError('User already blocked', 409);
    }
    throw err;
  }

  try {
    await withTransaction(async (session) => {
      const opts = sessionOpt(session);

      const existing = await Match.find(
        { users: { $all: [blockerId, blockedId] } },
        { _id: 1 },
        opts,
      );
      const matchIds = existing.map((m) => m._id);

      if (matchIds.length > 0) {
        await Message.deleteMany({ matchId: { $in: matchIds } }, opts);
      }
      await Match.deleteMany(
        { users: { $all: [blockerId, blockedId] } },
        opts,
      );
      await Like.deleteMany(
        {
          $or: [
            { fromUser: blockerId, toUser: blockedId },
            { fromUser: blockedId, toUser: blockerId },
          ],
        },
        opts,
      );
    });
  } catch (err) {
    // Best-effort cleanup; the Block exists already, propagate the error so
    // the caller knows the cascade failed.
    logger.error({ err: err.message }, 'Block cascade failed after Block.create');
    throw err;
  }

  return { message: 'User blocked' };
};

module.exports = { reportUser, blockUser };
