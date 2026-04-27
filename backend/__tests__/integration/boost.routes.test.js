// Mock stripe BEFORE requiring testApp (which loads the app)
jest.mock('../../src/config/stripe', () => ({
  checkout: { sessions: { create: jest.fn() } },
  webhooks: { constructEvent: jest.fn() },
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

describe('POST /api/v1/boost/webhook — idempotency', () => {
  it('processes a new Stripe checkout.session.completed event and activates boost', async () => {
    const fakeEvent = {
      id: 'evt_unique_001',
      type: 'checkout.session.completed',
      data: {
        object: {
          metadata: { userId: maleUser._id.toString(), tier: 'bronze', duration: '1' },
        },
      },
    };

    mockStripe.webhooks.constructEvent.mockReturnValue(fakeEvent);

    const res = await request(app)
      .post('/api/v1/boost/webhook')
      .set('stripe-signature', 'sig_test')
      .set('Content-Type', 'application/json')
      .send(JSON.stringify(fakeEvent));

    expect(res.status).toBe(200);

    const boostedUser = await User.findById(maleUser._id);
    expect(boostedUser.boostLevel).toBe('bronze');
  });

  it('skips duplicate Stripe events (idempotency key)', async () => {
    await WebhookEvent.create({ eventId: 'evt_duplicate', type: 'checkout.session.completed' });

    const duplicateEvent = {
      id: 'evt_duplicate',
      type: 'checkout.session.completed',
      data: {
        object: {
          metadata: { userId: maleUser._id.toString(), tier: 'gold', duration: '7' },
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

    // boostLevel should NOT be changed since the event was already processed
    const notBoosted = await User.findById(maleUser._id);
    expect(notBoosted.boostLevel).toBe('none');
  });
});
