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
 */
const deleteAccount = async (userId) => {
  const user = await User.findById(userId);
  if (!user) throw new AppError('User not found', 404);

  // 1. Delete all photos from Cloudinary
  if (user.photos && user.photos.length > 0) {
    const deletePromises = user.photos.map((photo) =>
      deleteImage(photo.publicId).catch((err) => {
        logger.warn({ publicId: photo.publicId, err: err.message }, 'Failed to delete photo during account deletion');
      })
    );
    await Promise.all(deletePromises);
  }

  // 2. Find all matches involving this user to delete messages
  const matches = await Match.find({ users: userId }).select('_id');
  const matchIds = matches.map((m) => m._id);

  // 3. Delete all associated data in parallel
  await Promise.all([
    // Delete messages in all matches
    matchIds.length > 0 ? Message.deleteMany({ matchId: { $in: matchIds } }) : Promise.resolve(),
    // Delete matches
    Match.deleteMany({ users: userId }),
    // Delete likes (sent and received)
    Like.deleteMany({ $or: [{ fromUser: userId }, { toUser: userId }] }),
    // Delete blocks
    Block.deleteMany({ $or: [{ blocker: userId }, { blocked: userId }] }),
    // Delete reports (as reporter — keep reports against this user for records)
    Report.deleteMany({ reporter: userId }),
    // Invalidate caches
    cacheDelPattern(`feed:${userId}:*`),
  ]);

  // 4. Delete user document
  await User.findByIdAndDelete(userId);

  logger.info({ userId }, 'Account deleted');

  return { message: 'Account deleted successfully' };
};

module.exports = { deleteAccount };
