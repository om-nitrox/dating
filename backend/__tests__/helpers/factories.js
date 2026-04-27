const crypto = require('crypto');
const User = require('../../src/models/User');
const Match = require('../../src/models/Match');
const Message = require('../../src/models/Message');
const Like = require('../../src/models/Like');
const Block = require('../../src/models/Block');

// crypto.randomUUID() guarantees uniqueness even under parallel test runs;
// Date.now() + Math.random() collides often enough to cause flakes.
const uniq = () => crypto.randomUUID().replace(/-/g, '');

const makeUser = (overrides = {}) => {
  const id = uniq();
  return User.create({
    email: `user_${id}@test.com`,
    name: 'Test User',
    gender: 'male',
    age: 25,
    dob: new Date('1999-01-01'),
    isProfileComplete: true,
    isActive: true,
    photos: [
      { url: 'https://example.com/a.jpg', publicId: `photo_a_${id}` },
      { url: 'https://example.com/b.jpg', publicId: `photo_b_${id}` },
    ],
    ...overrides,
  });
};

const makeMatch = (user1Id, user2Id, overrides = {}) =>
  Match.create({ users: [user1Id, user2Id], ...overrides });

const makeMessage = (matchId, senderId, text = 'Hello', overrides = {}) => Message.create({
  matchId,
  sender: senderId,
  text,
  ...overrides,
});

const makeLike = (fromUserId, toUserId, status = 'pending') =>
  Like.create({ fromUser: fromUserId, toUser: toUserId, status });

const makeBlock = (blockerId, blockedId) => Block.create({
  blocker: blockerId,
  blocked: blockedId,
});

module.exports = {
  makeUser,
  makeMatch,
  makeMessage,
  makeLike,
  makeBlock,
};
