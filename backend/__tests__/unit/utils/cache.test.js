const mockRedis = {
  status: 'ready',
  get: jest.fn(),
  set: jest.fn(),
  del: jest.fn(),
  scan: jest.fn(),
};

jest.mock('../../../src/config/redis', () => ({
  getRedis: () => mockRedis,
}));

const { cacheGet, cacheSet, cacheDel, cacheDelPattern } = require('../../../src/utils/cache');

beforeEach(() => jest.clearAllMocks());

describe('cacheGet', () => {
  it('returns parsed JSON value from Redis', async () => {
    mockRedis.get.mockResolvedValue(JSON.stringify({ foo: 'bar' }));

    const result = await cacheGet('my-key');
    expect(result).toEqual({ foo: 'bar' });
    expect(mockRedis.get).toHaveBeenCalledWith('my-key');
  });

  it('returns null on cache miss', async () => {
    mockRedis.get.mockResolvedValue(null);

    const result = await cacheGet('missing-key');
    expect(result).toBeNull();
  });
});

describe('cacheSet', () => {
  it('stores JSON-serialized value with TTL', async () => {
    mockRedis.set.mockResolvedValue('OK');

    await cacheSet('my-key', { a: 1 }, 120);

    expect(mockRedis.set).toHaveBeenCalledWith('my-key', JSON.stringify({ a: 1 }), 'EX', 120);
  });
});

describe('cacheDel', () => {
  it('calls Redis del with the given key', async () => {
    mockRedis.del.mockResolvedValue(1);

    await cacheDel('my-key');
    expect(mockRedis.del).toHaveBeenCalledWith('my-key');
  });
});

describe('cacheDelPattern', () => {
  it('scans and deletes matching keys', async () => {
    mockRedis.scan
      .mockResolvedValueOnce(['42', ['key:1', 'key:2']])
      .mockResolvedValueOnce(['0', []]);
    mockRedis.del.mockResolvedValue(2);

    await cacheDelPattern('key:*');

    expect(mockRedis.del).toHaveBeenCalledWith('key:1', 'key:2');
  });

  it('does nothing when no keys match', async () => {
    mockRedis.scan.mockResolvedValue(['0', []]);

    await cacheDelPattern('nomatch:*');

    expect(mockRedis.del).not.toHaveBeenCalled();
  });
});
