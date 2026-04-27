jest.mock('../../../src/models/User');
jest.mock('../../../src/models/Like');
jest.mock('../../../src/models/Block');
jest.mock('../../../src/services/notification.service');
jest.mock('../../../src/utils/cache', () => ({
  cacheGet: jest.fn().mockResolvedValue(null),
  cacheSet: jest.fn().mockResolvedValue(undefined),
  cacheDel: jest.fn().mockResolvedValue(undefined),
}));

const mongoose = require('mongoose');
const User = require('../../../src/models/User');
const Like = require('../../../src/models/Like');
const Block = require('../../../src/models/Block');
const { sendPush } = require('../../../src/services/notification.service');
const { getFeed, like, skip, undoLastSkip } = require('../../../src/services/swipe.service');

const userId = new mongoose.Types.ObjectId().toString();
const targetId = new mongoose.Types.ObjectId().toString();

beforeEach(() => jest.clearAllMocks());

describe('getFeed', () => {
  it('returns cached results when cache hit', async () => {
    const { cacheGet } = require('../../../src/utils/cache');
    cacheGet.mockResolvedValueOnce({ profiles: [], nextCursor: null });

    const result = await getFeed(userId, null, 20);
    expect(result.profiles).toEqual([]);
  });

  it('excludes already-interacted users', async () => {
    User.findById = jest.fn().mockReturnValue({
      select: jest.fn().mockReturnValue({
        lean: jest.fn().mockResolvedValue({
          location: { coordinates: [0, 0] },
          preferences: { ageMin: 18, ageMax: 50, maxDistance: 50 },
        }),
      }),
    });
    Like.find = jest.fn().mockReturnValue({ distinct: jest.fn().mockResolvedValue([targetId]) });
    Block.find = jest.fn().mockResolvedValue([]);
    User.aggregate = jest.fn().mockReturnValue({ option: jest.fn().mockResolvedValue([]) });

    await getFeed(userId, null, 20);
    expect(User.aggregate).toHaveBeenCalled();
  });
});

describe('like', () => {
  it('creates Like record and sends push notification', async () => {
    User.findById = jest.fn().mockResolvedValue({ _id: targetId, gender: 'male' });
    Like.create = jest.fn().mockResolvedValue({});

    await like(userId, targetId);

    expect(Like.create).toHaveBeenCalledWith(
      expect.objectContaining({ fromUser: userId, toUser: targetId, status: 'pending' })
    );
    expect(sendPush).toHaveBeenCalledWith(targetId, 'New Like!', expect.any(String), expect.any(Object));
  });

  it('throws 409 on duplicate like', async () => {
    User.findById = jest.fn().mockResolvedValue({ _id: targetId, gender: 'male' });
    Like.create = jest.fn().mockRejectedValue({ code: 11000 });

    await expect(like(userId, targetId)).rejects.toThrow('Already liked');
  });

  it('throws if user tries to like themselves', async () => {
    await expect(like(userId, userId)).rejects.toThrow('Cannot like yourself');
  });
});

describe('skip', () => {
  it('creates skipped Like record', async () => {
    Like.create = jest.fn().mockResolvedValue({});

    const result = await skip(userId, targetId);

    expect(Like.create).toHaveBeenCalledWith(
      expect.objectContaining({ status: 'skipped' })
    );
    expect(result.message).toBe('Skipped');
  });
});

describe('undoLastSkip', () => {
  it('throws 404 when no recent skip exists', async () => {
    Like.findOne = jest.fn().mockReturnValue({
      sort: jest.fn().mockResolvedValue(null),
    });

    await expect(undoLastSkip(userId)).rejects.toThrow('No recent skip to undo');
  });

  it('throws 400 when skip is too old', async () => {
    Like.findOne = jest.fn().mockReturnValue({
      sort: jest.fn().mockResolvedValue({
        _id: 'like1',
        toUser: targetId,
        createdAt: new Date(Date.now() - 10 * 60 * 1000),
      }),
    });

    await expect(undoLastSkip(userId)).rejects.toThrow('too old to undo');
  });

  it('deletes the skip and invalidates cache on success', async () => {
    Like.findOne = jest.fn().mockReturnValue({
      sort: jest.fn().mockResolvedValue({
        _id: 'like1',
        toUser: targetId,
        createdAt: new Date(Date.now() - 60 * 1000),
      }),
    });
    Like.findByIdAndDelete = jest.fn().mockResolvedValue({});

    const result = await undoLastSkip(userId);
    expect(Like.findByIdAndDelete).toHaveBeenCalledWith('like1');
    expect(result.undoneUserId).toBe(targetId);
  });
});
