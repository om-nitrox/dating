/**
 * Unit tests for Stripe webhook idempotency (fix 13).
 *
 * The handler MUST use a single upsert on WebhookEvent so the
 * find-then-create TOCTOU window cannot let two concurrent deliveries both
 * activate a boost. `activateBoost` should fire only when
 * `WebhookEvent.updateOne(..., { upsert: true })` reports `upsertedCount === 1`.
 */

const mockStripe = {
  webhooks: {
    constructEvent: jest.fn(),
  },
};

jest.mock('../../../src/models/User');
jest.mock('../../../src/models/WebhookEvent');
jest.mock('../../../src/config/stripe', () => mockStripe);
jest.mock('../../../src/config', () => ({
  stripeWebhookSecret: 'whsec_test',
  nodeEnv: 'test',
  appDeepLinkScheme: 'reversematch',
  appBaseUrl: 'http://localhost:5000',
}));

const User = require('../../../src/models/User');
const WebhookEvent = require('../../../src/models/WebhookEvent');
const { handleStripeWebhook } = require('../../../src/services/boost.service');

beforeEach(() => {
  jest.clearAllMocks();
  User.findByIdAndUpdate = jest.fn().mockResolvedValue({});
});

const makeEvent = (id = 'evt_1') => ({
  id,
  type: 'checkout.session.completed',
  data: {
    object: {
      metadata: {
        userId: 'user_123',
        tier: 'gold',
        durationMinutes: '180',
      },
    },
  },
});

describe('handleStripeWebhook idempotency (fix 13)', () => {
  it('activates the boost exactly once on first delivery (upsertedCount=1)', async () => {
    mockStripe.webhooks.constructEvent.mockReturnValue(makeEvent('evt_first'));
    WebhookEvent.updateOne = jest.fn().mockResolvedValue({ upsertedCount: 1 });

    await handleStripeWebhook(Buffer.from('payload'), 'sig');

    expect(WebhookEvent.updateOne).toHaveBeenCalledWith(
      { eventId: 'evt_first' },
      expect.objectContaining({
        $setOnInsert: expect.objectContaining({ eventId: 'evt_first' }),
      }),
      { upsert: true },
    );
    expect(User.findByIdAndUpdate).toHaveBeenCalledTimes(1);
  });

  it('SKIPS the side-effect on a duplicate delivery (upsertedCount=0)', async () => {
    mockStripe.webhooks.constructEvent.mockReturnValue(makeEvent('evt_dupe'));
    WebhookEvent.updateOne = jest.fn().mockResolvedValue({ upsertedCount: 0 });

    await handleStripeWebhook(Buffer.from('payload'), 'sig');

    expect(WebhookEvent.updateOne).toHaveBeenCalledTimes(1);
    expect(User.findByIdAndUpdate).not.toHaveBeenCalled();
  });

  it('activates only ONCE even when called twice concurrently', async () => {
    mockStripe.webhooks.constructEvent.mockReturnValue(makeEvent('evt_race'));

    // First caller upserts (count=1), second caller sees the existing row (count=0).
    let calls = 0;
    WebhookEvent.updateOne = jest.fn().mockImplementation(async () => {
      calls += 1;
      return { upsertedCount: calls === 1 ? 1 : 0 };
    });

    await Promise.all([
      handleStripeWebhook(Buffer.from('payload'), 'sig'),
      handleStripeWebhook(Buffer.from('payload'), 'sig'),
    ]);

    expect(User.findByIdAndUpdate).toHaveBeenCalledTimes(1);
  });
});
