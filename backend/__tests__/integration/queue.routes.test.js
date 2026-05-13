// Phase 0.3: validator codegen + queue pagination.
//
// Asserts the contract for /api/v1/queue:
//   - response shape is `{ likes, hasMore }` (NOT the old `{ likes }` only)
//   - page/limit are honored
//   - boosted senders surface ahead of non-boosted ones on page 1
//   - 400 when page/limit are out of range (via the generated zod schema)

const { startTestApp, stopTestApp, clearDB } = require('../helpers/testApp');
const request = require('supertest');
const { signAccessToken } = require('../../src/utils/token');
const User = require('../../src/models/User');
const Like = require('../../src/models/Like');

let app;
let boy;
let boyToken;

beforeAll(async () => {
  app = await startTestApp();
});

afterAll(async () => {
  await stopTestApp();
});

beforeEach(async () => {
  boy = await User.create({
    email: 'queue-recipient@test.com',
    name: 'Recipient',
    gender: 'male',
    age: 27,
    dob: new Date('1997-01-01'),
    isProfileComplete: true,
  });
  boyToken = signAccessToken(boy._id, boy.gender);
});

afterEach(async () => {
  await clearDB();
});

const seedLikes = async (count, { boostedSenderIndices = [] } = {}) => {
  for (let i = 0; i < count; i++) {
    // eslint-disable-next-line no-await-in-loop
    const sender = await User.create({
      email: `sender${i}@test.com`,
      name: `Sender ${i}`,
      gender: 'female',
      age: 25,
      dob: new Date('1999-01-01'),
      boostLevel: boostedSenderIndices.includes(i) ? 'gold' : 'none',
      boostExpiry: boostedSenderIndices.includes(i)
        ? new Date(Date.now() + 60 * 60 * 1000)
        : null,
      isProfileComplete: true,
    });
    // eslint-disable-next-line no-await-in-loop
    await Like.create({
      fromUser: sender._id,
      toUser: boy._id,
      status: 'pending',
      type: 'like',
    });
  }
};

describe('GET /api/v1/queue', () => {
  it('returns { likes, hasMore } even when empty', async () => {
    const res = await request(app)
      .get('/api/v1/queue')
      .set('Authorization', `Bearer ${boyToken}`);

    expect(res.status).toBe(200);
    expect(res.body).toEqual({ likes: [], hasMore: false });
  });

  it('honors page and limit, sets hasMore true when more rows remain', async () => {
    await seedLikes(5);

    const res = await request(app)
      .get('/api/v1/queue?page=1&limit=2')
      .set('Authorization', `Bearer ${boyToken}`);

    expect(res.status).toBe(200);
    expect(res.body.likes).toHaveLength(2);
    expect(res.body.hasMore).toBe(true);
  });

  it('returns hasMore=false on the last page', async () => {
    await seedLikes(3);

    const res = await request(app)
      .get('/api/v1/queue?page=2&limit=2')
      .set('Authorization', `Bearer ${boyToken}`);

    expect(res.status).toBe(200);
    expect(res.body.likes).toHaveLength(1);
    expect(res.body.hasMore).toBe(false);
  });

  it('boosted senders sort ahead of non-boosted on page 1', async () => {
    // Seed 4 likes — indexes 2 and 3 are gold-boosted.
    await seedLikes(4, { boostedSenderIndices: [2, 3] });

    const res = await request(app)
      .get('/api/v1/queue?page=1&limit=4')
      .set('Authorization', `Bearer ${boyToken}`);

    expect(res.status).toBe(200);
    expect(res.body.likes).toHaveLength(4);
    // The first two entries must be from the boosted senders. Sender names
    // were "Sender 2" / "Sender 3".
    const topNames = res.body.likes.slice(0, 2).map((l) => l.fromUser.name).sort();
    expect(topNames).toEqual(['Sender 2', 'Sender 3']);
  });

  it('rejects limit > 100 with 400', async () => {
    const res = await request(app)
      .get('/api/v1/queue?limit=500')
      .set('Authorization', `Bearer ${boyToken}`);

    expect(res.status).toBe(400);
  });

  it('rejects page < 1 with 400', async () => {
    const res = await request(app)
      .get('/api/v1/queue?page=0')
      .set('Authorization', `Bearer ${boyToken}`);

    expect(res.status).toBe(400);
  });

  it('accepts omitted page/limit (defaults page=1, limit=20)', async () => {
    await seedLikes(3);

    const res = await request(app)
      .get('/api/v1/queue')
      .set('Authorization', `Bearer ${boyToken}`);

    expect(res.status).toBe(200);
    expect(res.body.likes).toHaveLength(3);
    expect(res.body.hasMore).toBe(false);
  });
});
