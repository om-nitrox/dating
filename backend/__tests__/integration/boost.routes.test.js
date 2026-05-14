// Mock stripe BEFORE requiring testApp (which loads the app)
jest.mock('../../src/config/stripe', () => ({
  checkout: { sessions: { create: jest.fn() } },
  webhooks: { constructEvent: jest.fn() },
}));

// Phase 1.1: webhook now enqueues a `boost.activate` job instead of writing
// to the User doc synchronously. Mock the queue so the integration test
// doesn't need a running Redis to capture the enqueue call.
const mockQueueAdd = jest.fn().mockResolvedValue({ id: 'job_test' });
jest.mock('../../src/queue', () => ({
  get defaultQueue() { return { add: mockQueueAdd }; },
}));

const { startTestApp, stopTestApp, clearDB } = require('../helpers/testApp');
const request = require('supertest');
const { signAccessToken } = require('../../src/utils/token');
const User = require('../../src/models/User');
const WebhookEvent = require('../../src/models/WebhookEvent');
// Get a reference to the mocked stripe module so we can configure its methods
const mockStripe = require('../../src/config/stripe');

let app;
let maleUser;
let maleToken;

beforeAll(async () => {
  app = await startTestApp();
});

afterAll(async () => {
  await stopTestApp();
});

beforeEach(async () => {
  maleUser = await User.create({
    email: 'boost@test.com',
    name: 'Boost User',
    gender: 'male',
    age: 25,
    dob: new Date('1999-01-01'),
  });
  maleToken = signAccessToken(maleUser._id, maleUser.gender);
});

afterEach(async () => {
  await clearDB();
  jest.clearAllMocks();
});

describe('POST /api/v1/boost/webhook — idempotency (Phase 1.1)', () => {
  it('enqueues a boost.activate job on first delivery (NOT synchronous DB write)', async () => {
    const fakeEvent = {
      id: 'evt_unique_001',
      type: 'checkout.session.completed',
      data: {
        object: {
          metadata: {
            userId: maleUser._id.toString(),
            tier: 'bronze',
            durationMinutes: '30',
          },
        },
      },
    };

    mockStripe.webhooks.constructEvent.mockReturnValue(fakeEvent);

    const res = await request(app)
      .post('/api/v1/boost/webhook')
      .set('stripe-signature', 'sig_test')
      .set('Content-Type', 'application/json')
      .send(JSON.stringify(fakeEvent));

    // Phase 1.1: synchronous response is 200 with no DB write — the boost
    // is activated asynchronously by the worker. We verify the job was
    // enqueued with the right payload.
    expect(res.status).toBe(200);
    expect(res.body.status).toBe('enqueued');

    expect(mockQueueAdd).toHaveBeenCalledTimes(1);
    expect(mockQueueAdd).toHaveBeenCalledWith(
      'boost.activate',
      expect.objectContaining({
        eventId: 'evt_unique_001',
        userId: maleUser._id.toString(),
        tier: 'bronze',
        durationMinutes: 30,
      }),
    );

    // The user doc must NOT have been written yet — that's the worker's job.
    const unboosted = await User.findById(maleUser._id);
    expect(unboosted.boostLevel).toBe('none');

    // And the WebhookEvent row should be present (dedupe gate).
    const evt = await WebhookEvent.findOne({ eventId: 'evt_unique_001' });
    expect(evt).not.toBeNull();
  });

  it('skips duplicate Stripe events (idempotency key)', async () => {
    await WebhookEvent.create({ eventId: 'evt_duplicate', type: 'checkout.session.completed' });

    const duplicateEvent = {
      id: 'evt_duplicate',
      type: 'checkout.session.completed',
      data: {
        object: {
          metadata: {
            userId: maleUser._id.toString(),
            tier: 'gold',
            durationMinutes: '180',
          },
        },
      },
    };

    mockStripe.webhooks.constructEvent.mockReturnValue(duplicateEvent);

    const res = await request(app)
      .post('/api/v1/boost/webhook')
      .set('stripe-signature', 'sig_test')
      .set('Content-Type', 'application/json')
      .send(JSON.stringify(duplicateEvent));

    expect(res.status).toBe(200);
    expect(res.body.status).toBe('duplicate');

    // No enqueue on duplicate.
    expect(mockQueueAdd).not.toHaveBeenCalled();

    // boostLevel should NOT be changed since the event was already processed
    const notBoosted = await User.findById(maleUser._id);
    expect(notBoosted.boostLevel).toBe('none');
  });
});
