const { startTestApp, stopTestApp, clearDB } = require('../helpers/testApp');
const request = require('supertest');
const { signAccessToken } = require('../../src/utils/token');
const User = require('../../src/models/User');

let app;
let femaleUser;
let maleUser;
let femaleToken;
let maleToken;

beforeAll(async () => {
  app = await startTestApp();
});

afterAll(async () => {
  await stopTestApp();
});

beforeEach(async () => {
  femaleUser = await User.create({
    email: 'female@test.com',
    name: 'Female User',
    gender: 'female',
    age: 25,
    dob: new Date('1999-01-01'),
    isProfileComplete: true,
    isActive: true,
    photos: [
      { url: 'https://example.com/a.jpg', publicId: 'fa' },
      { url: 'https://example.com/b.jpg', publicId: 'fb' },
    ],
  });

  maleUser = await User.create({
    email: 'male@test.com',
    name: 'Male User',
    gender: 'male',
    age: 27,
    dob: new Date('1997-01-01'),
    isProfileComplete: true,
    isActive: true,
    photos: [
      { url: 'https://example.com/c.jpg', publicId: 'mc' },
      { url: 'https://example.com/d.jpg', publicId: 'md' },
    ],
  });

  femaleToken = signAccessToken(femaleUser._id, femaleUser.gender);
  maleToken = signAccessToken(maleUser._id, maleUser.gender);
});

afterEach(async () => {
  await clearDB();
});

describe('GET /api/v1/swipe/feed', () => {
  it('returns 200 for female user', async () => {
    const res = await request(app)
      .get('/api/v1/swipe/feed')
      .set('Authorization', `Bearer ${femaleToken}`);

    expect(res.status).toBe(200);
    expect(res.body.profiles).toBeDefined();
  });

  it('returns 403 for male user (female-only route)', async () => {
    const res = await request(app)
      .get('/api/v1/swipe/feed')
      .set('Authorization', `Bearer ${maleToken}`);

    expect(res.status).toBe(403);
  });

  it('returns 401 without auth', async () => {
    const res = await request(app).get('/api/v1/swipe/feed');
    expect(res.status).toBe(401);
  });
});

describe('POST /api/v1/swipe/like', () => {
  it('creates a like from female to male', async () => {
    const res = await request(app)
      .post('/api/v1/swipe/like')
      .set('Authorization', `Bearer ${femaleToken}`)
      .send({ userId: maleUser._id.toString() });

    expect(res.status).toBe(201);
    expect(res.body.message).toMatch(/like/i);
  });

  it('returns 404 for non-existent target user', async () => {
    const fakeId = '507f1f77bcf86cd799439011';
    const res = await request(app)
      .post('/api/v1/swipe/like')
      .set('Authorization', `Bearer ${femaleToken}`)
      .send({ userId: fakeId });

    expect(res.status).toBe(404);
  });
});

describe('POST /api/v1/swipe/skip', () => {
  it('records a skip', async () => {
    const res = await request(app)
      .post('/api/v1/swipe/skip')
      .set('Authorization', `Bearer ${femaleToken}`)
      .send({ userId: maleUser._id.toString() });

    expect(res.status).toBe(200);
    expect(res.body.message).toMatch(/skip/i);
  });
});
