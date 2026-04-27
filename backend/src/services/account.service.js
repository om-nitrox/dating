const User = require('../models/User');
const Like = require('../models/Like');
const Match = require('../models/Match');
const Message = require('../models/Message');
const Block = require('../models/Block');
const Report = require('../models/Report');
const { deleteImage } = require('./upload.service');
const AppError = require('../utils/AppError');
const logger = require('../utils/logger');
const { cacheDelPattern } = require('../utils/cache');

/**
 * Permanently delete a user account and all associated data.
 * Steps run in a logical order; related documents are removed before the user doc.
 */
const deleteAccount = async (userId) => {
  const user = await User.findById(userId);
  if (!user) throw new AppError('User not found', 404);

  // 1. Revoke all FCM tokens (in-memory, before deletion)
  if (user.fcmTokens && user.fcmTokens.length > 0) {
    user.fcmTokens = [];
    await user.save();
  }

  // 2. Delete all photos from Cloudinary (profile + selfie)
  const imageDeleteJobs = [];

  if (user.photos && user.photos.length > 0) {
    user.photos.forEach((photo) => {
      imageDeleteJobs.push(
        deleteImage(photo.publicId).catch((err) => {
          logger.warn({ publicId: photo.publicId, err: err.message }, 'Failed to delete photo during account deletion');
        }),
      );
    });
  }

  if (user.selfiePhoto?.publicId) {
    imageDeleteJobs.push(
      deleteImage(user.selfiePhoto.publicId).catch((err) => {
        logger.warn({ publicId: user.selfiePhoto.publicId, err: err.message }, 'Failed to delete selfie during account deletion');
      }),
    );
  }

  await Promise.all(imageDeleteJobs);

  // 3. Find all matches to be able to delete their messages
  const matches = await Match.find({ users: userId }).select('_id');
  const matchIds = matches.map((m) => m._id);

  // 4. Delete all associated data in parallel
  await Promise.all([
    matchIds.length > 0
      ? Message.deleteMany({ matchId: { $in: matchIds } })
      : Promise.resolve(),
    Match.deleteMany({ users: userId }),
    Like.deleteMany({ $or: [{ fromUser: userId }, { toUser: userId }] }),
    Block.deleteMany({ $or: [{ blocker: userId }, { blocked: userId }] }),
    Report.deleteMany({ reporter: userId }),
    cacheDelPattern(`feed:${userId}:*`),
    cacheDelPattern(`exclude:${userId}`),
  ]);

  // 5. Delete user document last
  await User.findByIdAndDelete(userId);

  logger.info({ userId }, 'Account deleted');

  return { message: 'Account deleted successfully' };
};

module.exports = { deleteAccount };
