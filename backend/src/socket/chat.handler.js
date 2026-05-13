const messageService = require('../services/message.service');
const Match = require('../models/Match');
const logger = require('../utils/logger');
const {
  emitNewMessage, emitUserTyping, emitMessagesSeen,
  emitSocketError, recordInboundEvent,
} = require('../realtime/events');

const MAX_MESSAGE_LENGTH = 2000;

/**
 * Socket.IO chat handler.
 * Inbound (client → server) and outbound (server → client) event names and
 * payload shapes mirror BACKEND_API.md §12.
 *
 * Logging: prefer `socket.data.log` (a pino child logger keyed by
 * `connection_id` — set in `socket/index.js`) so every chat log line is
 * correlatable to the originating socket. Falls back to the root logger if
 * the connection metadata is missing.
 */
const chatHandler = (io, socket) => {
  const log = socket.data?.log || logger;

  // Join a match room for real-time chat
  socket.on('join-room', async (matchId) => {
    recordInboundEvent('join-room');
    try {
      if (!matchId || typeof matchId !== 'string') return;

      const match = await Match.findById(matchId);
      if (!match) return;

      const isParticipant = match.users.some(
        (u) => u.toString() === socket.user.id,
      );

      if (!isParticipant) return;

      socket.join(matchId);
      log.debug({ matchId }, 'Joined chat room');
    } catch (err) {
      log.warn({ err: err.message }, 'join-room error');
    }
  });

  // Leave a match room
  socket.on('leave-room', (matchId) => {
    recordInboundEvent('leave-room');
    if (matchId && typeof matchId === 'string') {
      socket.leave(matchId);
    }
  });

  // Send a message via socket (also has an HTTP path — POST /messages)
  socket.on('send-message', async ({ matchId, text }) => {
    recordInboundEvent('send-message');
    try {
      if (!matchId || typeof matchId !== 'string') {
        return emitSocketError(socket, { message: 'Invalid matchId' });
      }
      if (!text || typeof text !== 'string') {
        return emitSocketError(socket, { message: 'Message text is required' });
      }

      const trimmed = text.trim();
      if (trimmed.length === 0) {
        return emitSocketError(socket, { message: 'Message cannot be empty' });
      }
      if (trimmed.length > MAX_MESSAGE_LENGTH) {
        return emitSocketError(socket, {
          message: `Message too long (max ${MAX_MESSAGE_LENGTH} characters)`,
        });
      }

      // Service returns { message, match } — fix 28 — so we don't re-fetch
      // the Match doc to fan out.
      const { message, match } = await messageService.sendMessage(
        matchId,
        socket.user.id,
        trimmed,
      );

      // Phase 0.6: route through the centralized event bus.
      emitNewMessage(io, {
        matchId,
        message,
        participantIds: match ? match.users : [],
        log,
      });
    } catch (err) {
      emitSocketError(socket, { message: err.message });
    }
  });

  // Typing indicator — spec §12 payload: { matchId, userId, isTyping: bool }.
  // Combine `typing-start` and `typing-stop` into a single `user-typing`
  // outbound event the frontend's SocketEventBus expects.
  socket.on('typing-start', (matchId) => {
    recordInboundEvent('typing-start');
    if (matchId && typeof matchId === 'string') {
      emitUserTyping(io, {
        matchId,
        userId: socket.user.id,
        isTyping: true,
        excludeSocket: socket,
        log,
      });
    }
  });

  socket.on('typing-stop', (matchId) => {
    recordInboundEvent('typing-stop');
    if (matchId && typeof matchId === 'string') {
      emitUserTyping(io, {
        matchId,
        userId: socket.user.id,
        isTyping: false,
        excludeSocket: socket,
        log,
      });
    }
  });

  // Read receipts — spec §12 payload: { matchId, seenAt: ISO-8601 }.
  socket.on('mark-seen', async (payload) => {
    recordInboundEvent('mark-seen');
    try {
      // Accept either `{ matchId }` (spec) or a raw matchId string for back-compat.
      const matchId = typeof payload === 'string' ? payload : payload?.matchId;
      if (!matchId || typeof matchId !== 'string') return;

      const seenAt = await messageService.markSeen(matchId, socket.user.id);

      // Phase 0.6: notify the OTHER user via the event bus. Bouncing into
      // the match room (excludeSocket) AND pushing into the other user's
      // personal room are both handled by emitMessagesSeen.
      const match = await Match.findById(matchId).select('users').lean();
      const otherId = match
        ? match.users.find((u) => u.toString() !== socket.user.id.toString())
        : null;

      emitMessagesSeen(io, {
        matchId,
        otherUserId: otherId,
        seenAt: seenAt.toISOString(),
        excludeSocket: socket,
        log,
      });
    } catch (err) {
      log.warn({ err: err.message }, 'mark-seen error');
    }
  });
};

module.exports = chatHandler;
