const { startTestApp, stopTestApp, clearDB } = require('../helpers/testApp');
const request = require('supertest');
const { signAccessToken } = require('../../src/utils/token');
const User = require('../../src/models/User');
const Match = require('../../src/models/Match');
const Message = require('../../src/models/Message');
const Like = require('../../src/models/Like');
const Block = require('../../src/models/Block');

// Mock Cloudinary so no real deletes happen
jest.mock('../../src/services/upload.service', () => ({
  uploadImage: jest.fn().mockResolvedValue({ url: 'https://cdn.example.com/photo.jpg', publicId: 'test/photo' }),
  deleteImage: jest.fn().mockResolvedValue({}),
}));

let app;
let user;
let token;

beforeAll(async () => {
  app = await startTestApp();
});

afterAll(async () => {
  await stopTestApp();
});

beforeEach(async () => {
  user = await User.create({
    email: 'todelete@test.com',
    name: 'To Delete',
    gender: 'female',
    age: 25,
    dob: new Date('1999-01-01'),
    photos: [{ url: 'https://example.com/a.jpg', publicId: 'photo_a' }],
    selfiePhoto: { url: 'https://example.com/s.jpg', publicId: 'selfie_s' },
  });
  token = signAccessToken(user._id, user.gender);
});

afterEach(async () => {
  await clearDB();
});

describe('DELETE /api/v1/account', () => {
  it('deletes user, photos, matches, messages, likes, and blocks', async () => {
    const otherUser = await User.create({
      email: 'other@test.com',
      dob: new Date('1995-01-01'),
    });

    const match = await Match.create({ users: [user._id, otherUser._id] });
    await Message.create({ matchId: match._id, sender: user._id, text: 'Hi' });
    await Like.create({ fromUser: user._id, toUser: otherUser._id, status: 'pending' });
    await Block.create({ blocker: user._id, blocked: otherUser._id });

    const res = await request(app)
      .delete('/api/v1/account')
      .set('Authorization', `Bearer ${token}`)
      .send({ confirmation: 'DELETE_MY_ACCOUNT' });

    expect(res.status).toBe(200);
    expect(res.body.message).toMatch(/deleted/i);

    expect(await User.findById(user._id)).toBeNull();
    expect(await Match.findById(match._id)).toBeNull();
    expect(await Message.countDocuments({ matchId: match._id })).toBe(0);
    expect(await Like.countDocuments({ fromUser: user._id })).toBe(0);
    expect(await Block.countDocuments({ blocker: user._id })).toBe(0);
  });

  it('returns 400 without confirmation string', async () => {
    const res = await request(app)
      .delete('/api/v1/account')
      .set('Authorization', `Bearer ${token}`)
      .send({ confirmation: 'wrong' });

    expect(res.status).toBe(400);
  });

  it('returns 401 without authentication', async () => {
    const res = await request(app)
      .delete('/api/v1/account')
      .send({ confirmation: 'DELETE_MY_ACCOUNT' });

    expect(res.status).toBe(401);
  });
});
