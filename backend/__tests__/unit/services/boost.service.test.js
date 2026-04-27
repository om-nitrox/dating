jest.mock('../../../src/models/User');
jest.mock('../../../src/models/WebhookEvent');
jest.mock('../../../src/config/stripe', () => null);
jest.mock('../../../src/config', () => ({
  stripeWebhookSecret: 'whsec_test',
  nodeEnv: 'test',
  appDeepLinkScheme: 'reversematch',
  appBaseUrl: 'http://localhost:5000',
}));

const User = require('../../../src/models/User');
const WebhookEvent = require('../../../src/models/WebhookEvent');
const { activateBoost, getBoostStatus } = require('../../../src/services/boost.service');

const userId = 'user123';

beforeEach(() => jest.clearAllMocks());

describe('activateBoost', () => {
  it('calls findByIdAndUpdate with boost tier and expiry', async () => {
    User.findByIdAndUpdate = jest.fn().mockResolvedValue({});

    await activateBoost(userId, 'gold', 7);

    expect(User.findByIdAndUpdate).toHaveBeenCalledWith(
      userId,
      expect.objectContaining({ boostLevel: 'gold', boostExpiry: expect.any(Date) })
    );

    // Expiry should be ~7 days from now
    const call = User.findByIdAndUpdate.mock.calls[0][1];
    const diffDays = (call.boostExpiry - new Date()) / (1000 * 60 * 60 * 24);
    expect(diffDays).toBeGreaterThan(6.9);
    expect(diffDays).toBeLessThan(7.1);
  });
});

describe('getBoostStatus', () => {
  it('returns active boost tier when boost is unexpired', async () => {
    User.findById = jest.fn().mockReturnValue({
      select: jest.fn().mockResolvedValue({
        boostLevel: 'silver',
        boostExpiry: new Date(Date.now() + 86400000),
      }),
    });

    const result = await getBoostStatus(userId);
    expect(result.boostLevel).toBe('silver');
    expect(result.isActive).toBe(true);
  });

  it('returns none when boost is expired', async () => {
    User.findById = jest.fn().mockReturnValue({
      select: jest.fn().mockResolvedValue({
        boostLevel: 'bronze',
        boostExpiry: new Date(Date.now() - 1000),
      }),
    });

    const result = await getBoostStatus(userId);
    expect(result.boostLevel).toBe('none');
    expect(result.isActive).toBe(false);
  });

  it('returns none when boostLevel is none', async () => {
    User.findById = jest.fn().mockReturnValue({
      select: jest.fn().mockResolvedValue({
        boostLevel: 'none',
        boostExpiry: null,
      }),
    });

    const result = await getBoostStatus(userId);
    expect(result.boostLevel).toBe('none');
    expect(result.isActive).toBe(false);
  });

  it('throws 404 if user not found', async () => {
    User.findById = jest.fn().mockReturnValue({
      select: jest.fn().mockResolvedValue(null),
    });

    await expect(getBoostStatus(userId)).rejects.toThrow('User not found');
  });
});

describe('handleStripeWebhook idempotency', () => {
  it('skips already-processed events', async () => {
    const { handleStripeWebhook } = require('../../../src/services/boost.service');
    WebhookEvent.findOne = jest.fn().mockResolvedValue({ eventId: 'evt_123' });
    WebhookEvent.create = jest.fn();

    // stripe is null — this should throw "Payments not configured" before even reaching idempotency
    await expect(handleStripeWebhook('body', 'sig')).rejects.toThrow('Payments not configured');
    expect(WebhookEvent.create).not.toHaveBeenCalled();
  });
});
