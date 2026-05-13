// Phase 0.6: realtime event-bus unit tests.
//
// Asserts each emit* function targets the right rooms with the right payload
// using a stub `io` (no real Socket.IO server). This is a contract test
// against docs/api/asyncapi.yaml — the helpers are now the single place
// the room-fan-out logic lives.

const {
  EVENTS,
  emitNewMessage,
  emitUserTyping,
  emitMessagesSeen,
  emitNewMatch,
  emitNewLike,
  emitMatchDeleted,
  emitSocketError,
} = require('../../../src/realtime/events');

// Build a Jest stub `io` that records every `.to(room).emit(event, payload)`
// call so each test can assert on the exact tuples.
const buildIoStub = () => {
  const calls = [];
  return {
    to(room) {
      return {
        emit(event, payload) {
          calls.push({ room, event, payload });
        },
      };
    },
    calls,
  };
};

const buildSocketStub = () => {
  const calls = [];
  return {
    to(room) {
      return {
        emit(event, payload) {
          calls.push({ scope: 'socket.to', room, event, payload });
        },
      };
    },
    emit(event, payload) {
      calls.push({ scope: 'socket', event, payload });
    },
    calls,
  };
};

describe('realtime/events', () => {
  describe('emitNewMessage', () => {
    it('fans new-message into match room + each participant personal room', () => {
      const io = buildIoStub();
      const message = {
        _id: 'a'.repeat(24),
        matchId: 'b'.repeat(24),
        sender: 'c'.repeat(24),
        text: 'hi',
        seen: false,
        createdAt: new Date().toISOString(),
      };
      emitNewMessage(io, {
        matchId: 'b'.repeat(24),
        message,
        participantIds: ['c'.repeat(24), 'd'.repeat(24)],
      });

      const rooms = io.calls.map((c) => c.room).sort();
      expect(rooms).toEqual(['b'.repeat(24), 'c'.repeat(24), 'd'.repeat(24)].sort());
      io.calls.forEach((c) => {
        expect(c.event).toBe(EVENTS.NEW_MESSAGE);
        expect(c.payload).toEqual({ matchId: 'b'.repeat(24), message });
      });
    });

    it('de-duplicates rooms (matchId equal to a participant id)', () => {
      const io = buildIoStub();
      const sameId = 'a'.repeat(24);
      emitNewMessage(io, {
        matchId: sameId,
        message: {
          _id: 'a'.repeat(24),
          matchId: sameId,
          sender: 'c'.repeat(24),
          text: 'hi',
          seen: false,
          createdAt: new Date().toISOString(),
        },
        participantIds: [sameId, 'd'.repeat(24)],
      });
      const rooms = io.calls.map((c) => c.room);
      expect(rooms.sort()).toEqual([sameId, 'd'.repeat(24)].sort());
    });

    it('is a no-op when io is falsy', () => {
      expect(() => emitNewMessage(null, {})).not.toThrow();
    });
  });

  describe('emitUserTyping', () => {
    it('uses socket.to when excludeSocket provided (skips the typer)', () => {
      const io = buildIoStub();
      const socket = buildSocketStub();
      emitUserTyping(io, {
        matchId: 'b'.repeat(24),
        userId: 'u'.repeat(24),
        isTyping: true,
        excludeSocket: socket,
      });
      expect(io.calls).toHaveLength(0);
      expect(socket.calls).toEqual([{
        scope: 'socket.to',
        room: 'b'.repeat(24),
        event: 'user-typing',
        payload: { matchId: 'b'.repeat(24), userId: 'u'.repeat(24), isTyping: true },
      }]);
    });

    it('falls back to io.to when no excludeSocket', () => {
      const io = buildIoStub();
      emitUserTyping(io, {
        matchId: 'b'.repeat(24),
        userId: 'u'.repeat(24),
        isTyping: false,
      });
      expect(io.calls).toEqual([{
        room: 'b'.repeat(24),
        event: 'user-typing',
        payload: { matchId: 'b'.repeat(24), userId: 'u'.repeat(24), isTyping: false },
      }]);
    });
  });

  describe('emitMessagesSeen', () => {
    it('emits to both the match room (via socket.to) and the other user room', () => {
      const io = buildIoStub();
      const socket = buildSocketStub();
      const seenAt = new Date().toISOString();
      emitMessagesSeen(io, {
        matchId: 'b'.repeat(24),
        otherUserId: 'o'.repeat(24),
        seenAt,
        excludeSocket: socket,
      });
      expect(socket.calls).toHaveLength(1);
      expect(socket.calls[0]).toMatchObject({
        room: 'b'.repeat(24),
        event: 'messages-seen',
        payload: { matchId: 'b'.repeat(24), seenAt },
      });
      expect(io.calls).toHaveLength(1);
      expect(io.calls[0]).toEqual({
        room: 'o'.repeat(24),
        event: 'messages-seen',
        payload: { matchId: 'b'.repeat(24), seenAt },
      });
    });
  });

  describe('emitNewMatch', () => {
    it('fans new-match to both participants personal rooms', () => {
      const io = buildIoStub();
      const match = {
        _id: 'm'.repeat(24),
        users: [{ _id: 'a'.repeat(24) }, { _id: 'b'.repeat(24) }],
        unreadCount: 0,
        createdAt: new Date().toISOString(),
      };
      emitNewMatch(io, { match });
      expect(io.calls.map((c) => c.room).sort()).toEqual(['a'.repeat(24), 'b'.repeat(24)].sort());
      io.calls.forEach((c) => {
        expect(c.event).toBe('new-match');
        expect(c.payload).toEqual({ match });
      });
    });
  });

  describe('emitNewLike', () => {
    it('targets only the recipient', () => {
      const io = buildIoStub();
      emitNewLike(io, { fromUserId: 'f'.repeat(24), toUserId: 't'.repeat(24) });
      expect(io.calls).toEqual([{
        room: 't'.repeat(24),
        event: 'new-like',
        payload: { fromUserId: 'f'.repeat(24) },
      }]);
    });

    it('is a no-op without toUserId', () => {
      const io = buildIoStub();
      emitNewLike(io, { fromUserId: 'f'.repeat(24) });
      expect(io.calls).toEqual([]);
    });
  });

  describe('emitMatchDeleted', () => {
    it('targets every participant except the actor', () => {
      const io = buildIoStub();
      emitMatchDeleted(io, {
        matchId: 'm'.repeat(24),
        participantIds: ['a'.repeat(24), 'b'.repeat(24)],
        actorId: 'a'.repeat(24),
      });
      expect(io.calls).toEqual([{
        room: 'b'.repeat(24),
        event: 'match-deleted',
        payload: { matchId: 'm'.repeat(24) },
      }]);
    });
  });

  describe('emitSocketError', () => {
    it('emits an error event back to the originating socket', () => {
      const socket = buildSocketStub();
      emitSocketError(socket, { message: 'oops' });
      expect(socket.calls).toEqual([{ scope: 'socket', event: 'error', payload: { message: 'oops' } }]);
    });
  });
});
