/**
 * Unit tests for Stripe webhook idempotency.
 *
 * Phase 1.1 redesign:
 *   The webhook MUST use a single WebhookEvent upsert so two concurrent
 *   deliveries can't both enqueue a boost.activate job. On `upsertedCount=1`
 *   (we won the race) the handler enqueues a BullMQ job and returns 200;
 *   `upsertedCount=0` (duplicate) returns 200 without enqueueing.
 *
 *   The job itself runs `activateBoost` (out-of-band), so the synchronous
 *   webhook path no longer calls `User.findByIdAndUpdate` — that's now the
 *   job worker's responsibility (`__tests__/unit/services/boost.service.test.js`
 *   covers activateBoost directly).
 */

const mockStripe = {
  webhooks: {
    constructEvent: jest.fn(),
  },
};

const mockQueueAdd = jest.fn().mockResolvedValue({ id: 'job_123' });

jest.mock('../../../src/models/User');
jest.mock('../../../src/models/WebhookEvent');
jest.mock('../../../src/config/stripe', () => mockStripe);
jest.mock('../../../src/config', () => ({
  stripeWebhookSecret: 'whsec_test',
  nodeEnv: 'test',
  appDeepLinkScheme: 'reversematch',
  appBaseUrl: 'http://localhost:5000',
}));
jest.mock('../../../src/queue', () => ({
  // Lazy getter so importing this mock doesn't open Redis sockets.
  get defaultQueue() { return { add: mockQueueAdd }; },
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

describe('handleStripeWebhook idempotency (Phase 1.1)', () => {
  it('enqueues the boost.activate job exactly once on first delivery', async () => {
    mockStripe.webhooks.constructEvent.mockReturnValue(makeEvent('evt_first'));
    WebhookEvent.updateOne = jest.fn().mockResolvedValue({ upsertedCount: 1 });

    const res = await handleStripeWebhook(Buffer.from('payload'), 'sig');

    expect(WebhookEvent.updateOne).toHaveBeenCalledWith(
      { eventId: 'evt_first' },
      expect.objectContaining({
        $setOnInsert: expect.objectContaining({ eventId: 'evt_first' }),
      }),
      { upsert: true },
    );
    // Side-effect is now an enqueue, NOT a direct DB write.
    expect(mockQueueAdd).toHaveBeenCalledTimes(1);
    expect(mockQueueAdd).toHaveBeenCalledWith(
      'boost.activate',
      expect.objectContaining({
        eventId: 'evt_first',
        userId: 'user_123',
        tier: 'gold',
        durationMinutes: 180,
      }),
    );
    expect(User.findByIdAndUpdate).not.toHaveBeenCalled();
    expect(res.status).toBe('enqueued');
  });

  it('SKIPS the enqueue on a duplicate delivery (upsertedCount=0)', async () => {
    mockStripe.webhooks.constructEvent.mockReturnValue(makeEvent('evt_dupe'));
    WebhookEvent.updateOne = jest.fn().mockResolvedValue({ upsertedCount: 0 });

    const res = await handleStripeWebhook(Buffer.from('payload'), 'sig');

    expect(WebhookEvent.updateOne).toHaveBeenCalledTimes(1);
    expect(mockQueueAdd).not.toHaveBeenCalled();
    expect(User.findByIdAndUpdate).not.toHaveBeenCalled();
    expect(res.status).toBe('duplicate');
  });

  it('enqueues only ONCE even when called twice concurrently', async () => {
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

    expect(mockQueueAdd).toHaveBeenCalledTimes(1);
  });
});
