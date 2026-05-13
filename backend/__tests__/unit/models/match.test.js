/**
 * Tests for the Match pair-uniqueness invariant (fix 12).
 *
 * We assert that:
 *   - Match.create with users in either order is canonicalised on save
 *   - A second concurrent insert with the same pair is rejected
 */

process.env.MONGO_URI = process.env.MONGO_URI || 'mongodb://localhost:27017/test';
process.env.JWT_ACCESS_SECRET = process.env.JWT_ACCESS_SECRET || 'test-access-secret-32-chars-long!!';
process.env.JWT_REFRESH_SECRET = process.env.JWT_REFRESH_SECRET || 'test-refresh-secret-32-chars-long!';

const mongoose = require('mongoose');
const { MongoMemoryServer } = require('mongodb-memory-server');
const Match = require('../../../src/models/Match');

let mongoServer;

beforeAll(async () => {
  mongoServer = await MongoMemoryServer.create();
  await mongoose.connect(mongoServer.getUri());
  // Ensure indexes (incl. unique compound) are built before tests run.
  await Match.init();
});

afterAll(async () => {
  await mongoose.disconnect();
  await mongoServer.stop();
});

afterEach(async () => {
  await Match.deleteMany({});
});

describe('Match unique pair invariant', () => {
  const makeIdPair = () => {
    const a = new mongoose.Types.ObjectId();
    const b = new mongoose.Types.ObjectId();
    return [a, b];
  };

  it('canonicalises users array order on save', async () => {
    const [a, b] = makeIdPair();
    // Force the larger id first; pre-save hook must reorder to [smaller, larger].
    const [low, high] = a.toString() < b.toString() ? [a, b] : [b, a];

    const m = await Match.create({ users: [high, low] });
    expect(m.users.map((u) => u.toString())).toEqual([low.toString(), high.toString()]);
  });

  it('rejects a duplicate pair regardless of insertion order', async () => {
    const [a, b] = makeIdPair();
    await Match.create({ users: [a, b] });

    let err;
    try {
      await Match.create({ users: [b, a] });
    } catch (e) {
      err = e;
    }
    expect(err).toBeDefined();
    expect(err.code).toBe(11000);
  });

  it('upsert-by-pair is idempotent under simulated race', async () => {
    const [a, b] = makeIdPair();
    const [low, high] = a.toString() < b.toString() ? [a, b] : [b, a];

    // Two concurrent upserts on the same pair — exactly one should insert.
    const upsert = () => Match.findOneAndUpdate(
      { users: [low, high] },
      { $setOnInsert: { users: [low, high] } },
      { upsert: true, new: true, setDefaultsOnInsert: true },
    );

    const results = await Promise.allSettled([upsert(), upsert(), upsert()]);
    const fulfilled = results.filter((r) => r.status === 'fulfilled');

    // At least one must succeed; we then assert the collection has exactly one row.
    expect(fulfilled.length).toBeGreaterThanOrEqual(1);
    const count = await Match.countDocuments({});
    expect(count).toBe(1);
  });
});
