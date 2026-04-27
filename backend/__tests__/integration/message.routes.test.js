const { startTestApp, stopTestApp, clearDB } = require('../helpers/testApp');
const request = require('supertest');
const { signAccessToken } = require('../../src/utils/token');
const User = require('../../src/models/User');
const Match = require('../../src/models/Match');
const Message = require('../../src/models/Message');

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
    email: 'sender@test.com',
    name: 'Sender',
    gender: 'female',
    age: 25,
    dob: new Date('1999-01-01'),
  });

  user2 = await User.create({
    email: 'recipient@test.com',
    name: 'Recipient',
    gender: 'male',
    age: 27,
    dob: new Date('1997-01-01'),
  });

  match = await Match.create({ users: [user1._id, user2._id] });
  token1 = signAccessToken(user1._id, user1.gender);
});

afterEach(async () => {
  await clearDB();
});

describe('POST /api/v1/messages', () => {
  it('creates a message in the match', async () => {
    const res = await request(app)
      .post('/api/v1/messages')
      .set('Authorization', `Bearer ${token1}`)
      .send({ matchId: match._id.toString(), text: 'Hello!' });

    expect(res.status).toBe(200);
    expect(res.body.text).toBe('Hello!');
    expect(res.body.seen).toBe(false);
  });

  it('returns 404 for non-existent match', async () => {
    const res = await request(app)
      .post('/api/v1/messages')
      .set('Authorization', `Bearer ${token1}`)
      .send({ matchId: '507f1f77bcf86cd799439011', text: 'Hello' });

    expect(res.status).toBe(404);
  });

  it('returns 400 when text is missing', async () => {
    const res = await request(app)
      .post('/api/v1/messages')
      .set('Authorization', `Bearer ${token1}`)
      .send({ matchId: match._id.toString() });

    expect(res.status).toBe(400);
  });
});

describe('GET /api/v1/messages/:matchId', () => {
  it('returns messages in chronological order with cursor pagination', async () => {
    await Message.create([
      { matchId: match._id, sender: user1._id, text: 'First' },
      { matchId: match._id, sender: user2._id, text: 'Second' },
    ]);

    const res = await request(app)
      .get(`/api/v1/messages/${match._id}`)
      .set('Authorization', `Bearer ${token1}`);

    expect(res.status).toBe(200);
    expect(res.body.messages).toHaveLength(2);
    expect(res.body.messages[0].text).toBe('First');
    expect(res.body.nextCursor).toBeNull();
  });

  it('returns 403 for non-participant', async () => {
    const outsider = await User.create({ email: 'out@test.com', dob: new Date('1995-01-01') });
    const outsiderToken = signAccessToken(outsider._id, outsider.gender);

    const res = await request(app)
      .get(`/api/v1/messages/${match._id}`)
      .set('Authorization', `Bearer ${outsiderToken}`);

    expect(res.status).toBe(403);
  });
});

describe('PUT /api/v1/messages/:matchId/seen', () => {
  it('marks messages as seen and persists seenAt to DB', async () => {
    const msg = await Message.create({
      matchId: match._id,
      sender: user2._id,
      text: 'Read me',
      seen: false,
    });

    const res = await request(app)
      .put(`/api/v1/messages/${match._id}/seen`)
      .set('Authorization', `Bearer ${token1}`);

    expect(res.status).toBe(200);

    const updated = await Message.findById(msg._id);
    expect(updated.seen).toBe(true);
    expect(updated.seenAt).toBeDefined();
  });
});
