const { startTestApp, stopTestApp, clearDB } = require('../helpers/testApp');
const request = require('supertest');
const { signAccessToken } = require('../../src/utils/token');
const User = require('../../src/models/User');

// Mock Cloudinary so no real uploads happen
jest.mock('../../src/services/upload.service', () => ({
  uploadImage: jest.fn().mockResolvedValue({ url: 'https://cdn.example.com/photo.jpg', publicId: 'test/photo123' }),
  deleteImage: jest.fn().mockResolvedValue({}),
  validateImageContent: jest.fn().mockResolvedValue(true),
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
    email: 'profile@test.com',
    name: 'Test User',
    gender: 'female',
    age: 25,
    dob: new Date('1999-01-01'),
    isProfileComplete: true,
    isActive: true,
    photos: [
      { url: 'https://example.com/a.jpg', publicId: 'photo_a' },
      { url: 'https://example.com/b.jpg', publicId: 'photo_b' },
    ],
  });
  token = signAccessToken(user._id, user.gender);
});

afterEach(async () => {
  await clearDB();
});

describe('GET /api/v1/profile', () => {
  it('returns current user profile when authenticated', async () => {
    const res = await request(app)
      .get('/api/v1/profile')
      .set('Authorization', `Bearer ${token}`);

    expect(res.status).toBe(200);
    expect(res.body.email).toBe('profile@test.com');
    expect(res.body.refreshToken).toBeUndefined();
    expect(res.body.fcmTokens).toBeUndefined();
  });

  it('returns 401 without token', async () => {
    const res = await request(app).get('/api/v1/profile');
    expect(res.status).toBe(401);
  });
});

describe('PUT /api/v1/profile', () => {
  it('updates allowed fields', async () => {
    const res = await request(app)
      .put('/api/v1/profile')
      .set('Authorization', `Bearer ${token}`)
      .send({ bio: 'Hello world', name: 'Updated Name' });

    expect(res.status).toBe(200);
    expect(res.body.bio).toBe('Hello world');
    expect(res.body.name).toBe('Updated Name');
  });

  it('rejects requests with no updatable fields', async () => {
    const res = await request(app)
      .put('/api/v1/profile')
      .set('Authorization', `Bearer ${token}`)
      .send({});

    expect(res.status).toBe(400);
  });
});

describe('POST /api/v1/profile/photos', () => {
  it('returns 400 if at max photo limit', async () => {
    // Fill user to max photos
    await User.findByIdAndUpdate(user._id, {
      photos: Array.from({ length: 6 }, (_, i) => ({
        url: `https://example.com/${i}.jpg`,
        publicId: `photo_${i}`,
      })),
    });

    const res = await request(app)
      .post('/api/v1/profile/photos')
      .set('Authorization', `Bearer ${token}`)
      .attach('photos', Buffer.from('fake-image-data'), { filename: 'test.jpg', contentType: 'image/jpeg' });

    expect(res.status).toBe(400);
    expect(res.body.message || res.body.error?.message).toMatch(/maximum/i);
  });
});
