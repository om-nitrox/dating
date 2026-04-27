jest.mock('../../../src/models/Match');
jest.mock('../../../src/models/Message');

const mongoose = require('mongoose');
const Match = require('../../../src/models/Match');
const Message = require('../../../src/models/Message');
const { getMatches, deleteMatch } = require('../../../src/services/match.service');

const userId = new mongoose.Types.ObjectId().toString();
const matchId = new mongoose.Types.ObjectId().toString();

beforeEach(() => jest.clearAllMocks());

describe('getMatches', () => {
  it('returns only matches for the requesting user', async () => {
    const fakeMatches = [{ _id: matchId, users: [userId], lastMessage: null, unreadCount: 0 }];
    Match.aggregate = jest.fn().mockResolvedValue(fakeMatches);

    const result = await getMatches(userId, null, 20);

    expect(Match.aggregate).toHaveBeenCalled();
    expect(result.matches).toEqual(fakeMatches);
  });

  it('returns nextCursor when more results exist', async () => {
    const fakeMatches = Array.from({ length: 21 }, (_, i) => ({
      _id: new mongoose.Types.ObjectId(),
      users: [userId],
    }));
    Match.aggregate = jest.fn().mockResolvedValue(fakeMatches);

    const result = await getMatches(userId, null, 20);

    expect(result.hasMore).toBe(true);
    expect(result.nextCursor).toBeTruthy();
    expect(result.matches).toHaveLength(20);
  });
});

describe('deleteMatch', () => {
  it('throws 404 if match not found', async () => {
    Match.findById = jest.fn().mockResolvedValue(null);

    await expect(deleteMatch(matchId, userId)).rejects.toThrow('Match not found');
  });

  it('throws 403 if user is not a participant', async () => {
    const otherId = new mongoose.Types.ObjectId().toString();
    Match.findById = jest.fn().mockResolvedValue({
      users: [new mongoose.Types.ObjectId(), new mongoose.Types.ObjectId()],
      toString: () => '',
    });

    await expect(deleteMatch(matchId, userId)).rejects.toThrow('Unauthorized');
  });

  it('deletes match and its messages on success', async () => {
    const userObjectId = new mongoose.Types.ObjectId(userId);
    Match.findById = jest.fn().mockResolvedValue({
      _id: matchId,
      users: [userObjectId],
    });
    Message.deleteMany = jest.fn().mockResolvedValue({});
    Match.findByIdAndDelete = jest.fn().mockResolvedValue({});

    const result = await deleteMatch(matchId, userId);

    expect(Message.deleteMany).toHaveBeenCalledWith({ matchId });
    expect(Match.findByIdAndDelete).toHaveBeenCalledWith(matchId);
    expect(result.message).toBe('Unmatched successfully');
  });
});
