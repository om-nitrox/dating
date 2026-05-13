/**
 * Integration tests for safety endpoints — focused on the report auto-suspend
 * threshold introduced in fix 18.
 *
 * NB: this hits the real Mongo-memory-server and real (mocked) Redis from
 * testApp helpers, so the cron/rate-limiter middleware is exercised end-to-end.
 */

// Set threshold BEFORE config is loaded.
process.env.REPORT_AUTO_SUSPEND_THRESHOLD = '3';

const { startTestApp, stopTestApp, clearDB } = require('../helpers/testApp');
const request = require('supertest');
const { signAccessToken } = require('../../src/utils/token');
const User = require('../../src/models/User');
const Report = require('../../src/models/Report');

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

describe('POST /api/v1/report (auto-suspend)', () => {
  it('auto-bans a user after REPORT_AUTO_SUSPEND_THRESHOLD pending reports', async () => {
    const target = await User.create({
      email: 'target@test.com',
      name: 'Target',
      gender: 'male',
      age: 25,
      dob: new Date('2000-01-01'),
    });

    // Three reporters — threshold env is 3 in this test file.
    const reporters = await Promise.all(
      [1, 2, 3].map((i) => User.create({
        email: `reporter${i}@test.com`,
        name: `R${i}`,
        gender: 'female',
        age: 25,
        dob: new Date('2000-01-01'),
      })),
    );

    for (const r of reporters) {
      const token = signAccessToken(r._id, r.gender);
      // eslint-disable-next-line no-await-in-loop
      const res = await request(app)
        .post('/api/v1/report')
        .set('Authorization', `Bearer ${token}`)
        .send({
          userId: target._id.toString(),
          reason: 'spam',
          details: 'auto-suspend integration test',
        });
      expect(res.status).toBe(200);
    }

    const after = await User.findById(target._id);
    expect(after.banned).toBe(true);

    // Three reports persisted.
    const count = await Report.countDocuments({ reported: target._id });
    expect(count).toBe(3);
  });

  it('does NOT ban below the threshold', async () => {
    const target = await User.create({
      email: 'target2@test.com',
      name: 'Target2',
      gender: 'male',
      age: 25,
      dob: new Date('2000-01-01'),
    });

    const reporter = await User.create({
      email: 'r-once@test.com',
      gender: 'female',
      age: 25,
      dob: new Date('2000-01-01'),
    });
    const token = signAccessToken(reporter._id, reporter.gender);

    const res = await request(app)
      .post('/api/v1/report')
      .set('Authorization', `Bearer ${token}`)
      .send({
        userId: target._id.toString(),
        reason: 'spam',
        details: 'one report',
      });
    expect(res.status).toBe(200);

    const after = await User.findById(target._id);
    expect(after.banned).toBe(false);
  });
});
