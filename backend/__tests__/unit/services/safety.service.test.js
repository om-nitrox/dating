jest.mock('../../../src/models/Report');
jest.mock('../../../src/models/Block');
jest.mock('../../../src/models/Match');
jest.mock('../../../src/models/Message');
jest.mock('../../../src/models/Like');

// Stub the transaction helper — service-level unit tests don't need a real
// Mongo session; they just invoke the work fn with `session=null` so writes
// run sequentially.
jest.mock('../../../src/utils/withTransaction', () => async (work) => work(null));

jest.mock('../../../src/config', () => ({
  reportAutoSuspendThreshold: 1000, // effectively disabled for blockUser tests
  nodeEnv: 'test',
}));

const mongoose = require('mongoose');
const Report = require('../../../src/models/Report');
const Block = require('../../../src/models/Block');
const Match = require('../../../src/models/Match');
const Message = require('../../../src/models/Message');
const Like = require('../../../src/models/Like');
const { reportUser, blockUser } = require('../../../src/services/safety.service');

const reporterId = new mongoose.Types.ObjectId().toString();
const reportedId = new mongoose.Types.ObjectId().toString();

beforeEach(() => jest.clearAllMocks());

describe('reportUser', () => {
  it('creates a Report record', async () => {
    Report.create = jest.fn().mockResolvedValue({});
    Report.countDocuments = jest.fn().mockResolvedValue(0);

    const result = await reportUser(reporterId, reportedId, 'spam', 'Spam content');

    expect(Report.create).toHaveBeenCalledWith(
      expect.objectContaining({ reporter: reporterId, reported: reportedId, reason: 'spam' }),
    );
    expect(result.message).toBe('Report submitted');
  });

  it('throws 400 if user reports themselves', async () => {
    await expect(reportUser(reporterId, reporterId, 'spam')).rejects.toThrow('Cannot report yourself');
  });
});

describe('blockUser', () => {
  it('creates Block record, removes matches/messages and likes', async () => {
    Block.create = jest.fn().mockResolvedValue({});
    // After the fix, Match.find is called with (filter, projection, opts).
    Match.find = jest.fn().mockResolvedValue([]);
    Match.deleteMany = jest.fn().mockResolvedValue({});
    Message.deleteMany = jest.fn().mockResolvedValue({});
    Like.deleteMany = jest.fn().mockResolvedValue({});

    const result = await blockUser(reporterId, reportedId);

    expect(Block.create).toHaveBeenCalledWith({ blocker: reporterId, blocked: reportedId });
    expect(Match.deleteMany).toHaveBeenCalled();
    expect(Like.deleteMany).toHaveBeenCalled();
    expect(result.message).toBe('User blocked');
  });

  it('throws 409 on duplicate block', async () => {
    Block.create = jest.fn().mockRejectedValue({ code: 11000 });

    await expect(blockUser(reporterId, reportedId)).rejects.toThrow('already blocked');
  });

  it('throws 400 if user blocks themselves', async () => {
    await expect(blockUser(reporterId, reporterId)).rejects.toThrow('Cannot block yourself');
  });
});
