const Like = require('../models/Like');
const Match = require('../models/Match');
const User = require('../models/User');
const AppError = require('../utils/AppError');
const { sendPush } = require('./notification.service');
const { cacheDel } = require('../utils/cache');

const getQueue = async (userId, page = 1, limit = 20) => {
  const skip = (page - 1) * limit;

  const [likes, total] = await Promise.all([
    Like.find({ toUser: userId, status: 'pending' })
      .populate('fromUser', 'name age bio photos interests location')
      .sort({ createdAt: -1 })
      .skip(skip)
      .limit(limit),
    Like.countDocuments({ toUser: userId, status: 'pending' }),
  ]);

  return {
    likes,
    page,
    totalPages: Math.ceil(total / limit),
    total,
    hasMore: skip + limit < total,
  };
};

const accept = async (userId, likeId) => {
  const like = await Like.findById(likeId);

  if (!like) throw new AppError('Like not found', 404);
  if (like.toUser.toString() !== userId.toString()) {
    throw new AppError('Unauthorized', 403);
  }
  if (like.status !== 'pending') {
    throw new AppError('Like already processed', 400);
  }

  // Update like status
  like.status = 'accepted';
  await like.save();

  // Create match
  const match = await Match.create({
    users: [like.fromUser, like.toUser],
  });

  // Reset boy's daysWithoutMatch
  await User.findByIdAndUpdate(userId, { daysWithoutMatch: 0 });

  // Invalidate feed cache for the girl (new match changes her exclusion list)
  await cacheDel(`feed:${like.fromUser}:20`);

  // Notify the girl
  sendPush(like.fromUser, "It's a Match!", 'Someone accepted your like!', {
    type: 'new_match',
    matchId: match._id.toString(),
  });

  // Populate match for response
  const populatedMatch = await Match.findById(match._id).populate(
    'users',
    'name age photos bio',
  );

  return populatedMatch;
};

const reject = async (userId, likeId) => {
  const like = await Like.findById(likeId);

  if (!like) throw new AppError('Like not found', 404);
  if (like.toUser.toString() !== userId.toString()) {
    throw new AppError('Unauthorized', 403);
  }
  if (like.status !== 'pending') {
    throw new AppError('Like already processed', 400);
  }

  like.status = 'rejected';
  await like.save();

  return { message: 'Rejected' };
};

module.exports = { getQueue, accept, reject };
