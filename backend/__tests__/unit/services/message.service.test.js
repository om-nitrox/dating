jest.mock('../../../src/models/Message');
jest.mock('../../../src/models/Match');
jest.mock('../../../src/services/notification.service', () => ({
  sendPush: jest.fn().mockResolvedValue(undefined),
}));

const mongoose = require('mongoose');
const Message = require('../../../src/models/Message');
const Match = require('../../../src/models/Match');
const { getMessages, sendMessage, markSeen } = require('../../../src/services/message.service');

const userId = new mongoose.Types.ObjectId().toString();
const recipientId = new mongoose.Types.ObjectId().toString();
const matchId = new mongoose.Types.ObjectId().toString();

const mockMatch = {
  _id: matchId,
  users: [new mongoose.Types.ObjectId(userId), new mongoose.Types.ObjectId(recipientId)],
};

beforeEach(() => jest.clearAllMocks());

describe('sendMessage', () => {
  it('creates a Message and returns it', async () => {
    Match.findById = jest.fn().mockResolvedValue(mockMatch);
    const mockMsg = { _id: 'msg1', matchId, sender: userId, text: 'Hello', seen: false };
    Message.create = jest.fn().mockResolvedValue(mockMsg);

    const result = await sendMessage(matchId, userId, 'Hello');

    expect(Message.create).toHaveBeenCalledWith({ matchId, sender: userId, text: 'Hello' });
    expect(result.text).toBe('Hello');
  });

  it('throws 403 if sender is not a participant', async () => {
    const outsiderId = new mongoose.Types.ObjectId().toString();
    Match.findById = jest.fn().mockResolvedValue(mockMatch);

    await expect(sendMessage(matchId, outsiderId, 'Hi')).rejects.toThrow('Unauthorized');
  });

  it('throws 404 if match does not exist', async () => {
    Match.findById = jest.fn().mockResolvedValue(null);

    await expect(sendMessage(matchId, userId, 'Hi')).rejects.toThrow('Match not found');
  });
});

describe('markSeen', () => {
  it('persists seen status to DB with seenAt timestamp', async () => {
    Message.updateMany = jest.fn().mockResolvedValue({ modifiedCount: 2 });

    await markSeen(matchId, userId);

    expect(Message.updateMany).toHaveBeenCalledWith(
      { matchId, sender: { $ne: userId }, seen: false },
      { seen: true, seenAt: expect.any(Date) }
    );
  });
});

describe('getMessages', () => {
  it('returns messages in chronological order with cursor pagination', async () => {
    Match.findById = jest.fn().mockResolvedValue(mockMatch);
    const msgs = [
      { _id: new mongoose.Types.ObjectId(), text: 'older', createdAt: new Date() },
      { _id: new mongoose.Types.ObjectId(), text: 'newer', createdAt: new Date() },
    ];
    Message.find = jest.fn().mockReturnValue({
      sort: jest.fn().mockReturnThis(),
      limit: jest.fn().mockReturnThis(),
      select: jest.fn().mockResolvedValue(msgs),
    });

    const result = await getMessages(matchId, userId, null, 30);

    expect(result.messages).toHaveLength(2);
    expect(result.hasMore).toBe(false);
  });
});
