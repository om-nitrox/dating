const { startTestApp, stopTestApp, clearDB } = require('../helpers/testApp');
const request = require('supertest');
const { signAccessToken } = require('../../src/utils/token');
const User = require('../../src/models/User');
const Otp = require('../../src/models/Otp');

let app;

beforeAll(async () => {
  app = await startTestApp();
});

afterAll(async () => {
  await stopTestApp();
});

afterEach(async () => {
  await clearDB();
});

describe('POST /api/v1/auth/signup', () => {
  it('returns 200 on valid email', async () => {
    const res = await request(app)
      .post('/api/v1/auth/signup')
      .send({ email: 'user@test.com' });

    expect(res.status).toBe(200);
    expect(res.body.message).toMatch(/OTP sent/i);
  });

  it('returns 400 on missing email', async () => {
    const res = await request(app)
      .post('/api/v1/auth/signup')
      .send({});

    expect(res.status).toBe(400);
  });

  it('returns 400 on invalid email format', async () => {
    const res = await request(app)
      .post('/api/v1/auth/signup')
      .send({ email: 'not-an-email' });

    expect(res.status).toBe(400);
  });
});

describe('POST /api/v1/auth/verify-otp', () => {
  it('returns 200 and tokens on correct OTP for existing user', async () => {
    const user = await User.create({
      email: 'existing@test.com',
      name: 'Existing User',
      dob: new Date('1995-01-01'),
    });

    await Otp.create({
      email: 'existing@test.com',
      code: '123456',
      expiresAt: new Date(Date.now() + 5 * 60 * 1000),
    });

    const res = await request(app)
      .post('/api/v1/auth/verify-otp')
      .send({ email: 'existing@test.com', code: '123456' });

    expect(res.status).toBe(200);
    expect(res.body.accessToken).toBeDefined();
    expect(res.body.refreshToken).toBeDefined();
  });

  it('returns 400 on wrong OTP', async () => {
    await Otp.create({
      email: 'user@test.com',
      code: '654321',
      expiresAt: new Date(Date.now() + 5 * 60 * 1000),
    });

    const res = await request(app)
      .post('/api/v1/auth/verify-otp')
      .send({ email: 'user@test.com', code: '000000' });

    expect(res.status).toBe(400);
  });

  it('requires dateOfBirth for new user', async () => {
    await Otp.create({
      email: 'newuser@test.com',
      code: '123456',
      expiresAt: new Date(Date.now() + 5 * 60 * 1000),
    });

    const res = await request(app)
      .post('/api/v1/auth/verify-otp')
      .send({ email: 'newuser@test.com', code: '123456' });

    expect(res.status).toBe(400);
    expect(res.body.message || res.body.error?.message).toMatch(/date of birth/i);
  });

  it('rejects underage new user', async () => {
    await Otp.create({
      email: 'young@test.com',
      code: '123456',
      expiresAt: new Date(Date.now() + 5 * 60 * 1000),
    });

    const res = await request(app)
      .post('/api/v1/auth/verify-otp')
      .send({ email: 'young@test.com', code: '123456', dateOfBirth: '2015-01-01' });

    expect(res.status).toBe(400);
    expect(res.body.message || res.body.error?.message).toMatch(/18/);
  });
});

describe('POST /api/v1/auth/refresh-token', () => {
  it('returns 400 on missing refreshToken', async () => {
    const res = await request(app)
      .post('/api/v1/auth/refresh-token')
      .send({});

    expect(res.status).toBe(400);
  });

  it('returns 401 on tampered token', async () => {
    const res = await request(app)
      .post('/api/v1/auth/refresh-token')
      .send({ refreshToken: 'not-a-real-token' });

    expect(res.status).toBe(401);
  });
});

describe('POST /api/v1/auth/logout', () => {
  it('returns 200 when authenticated', async () => {
    const user = await User.create({
      email: 'logout@test.com',
      dob: new Date('1995-01-01'),
    });

    const token = signAccessToken(user._id, user.gender);

    const res = await request(app)
      .post('/api/v1/auth/logout')
      .set('Authorization', `Bearer ${token}`);

    expect(res.status).toBe(200);
    expect(res.body.message).toMatch(/logged out/i);
  });

  it('returns 401 without token', async () => {
    const res = await request(app).post('/api/v1/auth/logout');
    expect(res.status).toBe(401);
  });
});
