const { startTestApp, stopTestApp, clearDB } = require('../helpers/testApp');
const request = require('supertest');
const { signAccessToken } = require('../../src/utils/token');
const User = require('../../src/models/User');
const Match = require('../../src/models/Match');

let app;
let user1;
let user2;
let match;
let token1;

beforeAll(async () => {
  app = await startTestApp();
});

afterAll(async () => {
  await stopTestApp();
});

beforeEach(async () => {
  user1 = await User.create({
    email: 'u1@test.com',
    name: 'User 1',
    gender: 'female',
    age: 25,
    dob: new Date('1999-01-01'),
    isProfileComplete: true,
  });

  user2 = await User.create({
    email: 'u2@test.com',
    name: 'User 2',
    gender: 'male',
    age: 27,
    dob: new Date('1997-01-01'),
    isProfileComplete: true,
  });

  match = await Match.create({ users: [user1._id, user2._id] });
  token1 = signAccessToken(user1._id, user1.gender);
});

afterEach(async () => {
  await clearDB();
});

describe('GET /api/v1/matches', () => {
  it('returns matches for the authenticated user with cursor pagination', async () => {
    const res = await request(app)
      .get('/api/v1/matches')
      .set('Authorization', `Bearer ${token1}`);

    expect(res.status).toBe(200);
    expect(res.body.matches).toHaveLength(1);
    expect(res.body.nextCursor).toBeDefined();
    expect(res.body.hasMore).toBe(false);
  });

  it('respects cursor parameter', async () => {
    const cursor = match._id.toString();
    const res = await request(app)
      .get(`/api/v1/matches?cursor=${cursor}`)
      .set('Authorization', `Bearer ${token1}`);

    expect(res.status).toBe(200);
    expect(res.body.matches).toHaveLength(0);
  });
});

describe('DELETE /api/v1/matches/:matchId', () => {
  it('unmatch — deletes match', async () => {
    const res = await request(app)
      .delete(`/api/v1/matches/${match._id}`)
      .set('Authorization', `Bearer ${token1}`);

    expect(res.status).toBe(200);
    expect(res.body.message).toMatch(/unmatched/i);

    const deleted = await Match.findById(match._id);
    expect(deleted).toBeNull();
  });

  it('returns 404 for non-existent match', async () => {
    const fakeId = '507f1f77bcf86cd799439011';
    const res = await request(app)
      .delete(`/api/v1/matches/${fakeId}`)
      .set('Authorization', `Bearer ${token1}`);

    expect(res.status).toBe(404);
  });

  it('returns 403 for non-participant', async () => {
    const outsider = await User.create({
      email: 'outsider@test.com',
      dob: new Date('1995-01-01'),
    });
    const outsiderToken = signAccessToken(outsider._id, outsider.gender);

    const res = await request(app)
      .delete(`/api/v1/matches/${match._id}`)
      .set('Authorization', `Bearer ${outsiderToken}`);

    expect(res.status).toBe(403);
  });
});
