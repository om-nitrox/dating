const messageService = require('../services/message.service');
const Match = require('../models/Match');
const logger = require('../utils/logger');

const MAX_MESSAGE_LENGTH = 2000;

/**
 * Socket.IO chat handler.
 * Inbound (client → server) and outbound (server → client) event names and
 * payload shapes mirror BACKEND_API.md §12.
 */
const chatHandler = (io, socket) => {
  // Join a match room for real-time chat
  socket.on('join-room', async (matchId) => {
    try {
      if (!matchId || typeof matchId !== 'string') return;

      const match = await Match.findById(matchId);
      if (!match) return;

      const isParticipant = match.users.some(
        (u) => u.toString() === socket.user.id,
      );

      if (!isParticipant) return;

      socket.join(matchId);
      logger.debug({ userId: socket.user.id, matchId }, 'Joined chat room');
    } catch (err) {
      logger.warn({ err: err.message }, 'join-room error');
    }
  });

  // Leave a match room
  socket.on('leave-room', (matchId) => {
    if (matchId && typeof matchId === 'string') {
      socket.leave(matchId);
    }
  });

  // Send a message via socket (also has an HTTP path — POST /messages)
  socket.on('send-message', async ({ matchId, text }) => {
    try {
      if (!matchId || typeof matchId !== 'string') {
        return socket.emit('error', { message: 'Invalid matchId' });
      }
      if (!text || typeof text !== 'string') {
        return socket.emit('error', { message: 'Message text is required' });
      }

      const trimmed = text.trim();
      if (trimmed.length === 0) {
        return socket.emit('error', { message: 'Message cannot be empty' });
      }
      if (trimmed.length > MAX_MESSAGE_LENGTH) {
        return socket.emit('error', {
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

      // Spec §12: `new-message` payload is `{ matchId, message }`.
      const payload = { matchId, message };

      // Broadcast inside the chat room (everyone with the chat open).
      io.to(matchId).emit('new-message', payload);

      // Also deliver to each participant's personal room so list badges
      // refresh even when the chat screen is closed.
      if (match) {
        match.users.forEach((u) => {
          io.to(u.toString()).emit('new-message', payload);
        });
      }
    } catch (err) {
      socket.emit('error', { message: err.message });
    }
  });

  // Typing indicator — spec §12 payload: { matchId, userId, isTyping: bool }.
  // Combine `typing-start` and `typing-stop` into a single `user-typing`
  // outbound event the frontend's SocketEventBus expects.
  socket.on('typing-start', (matchId) => {
    if (matchId && typeof matchId === 'string') {
      socket.to(matchId).emit('user-typing', {
        matchId,
        userId: socket.user.id,
        isTyping: true,
      });
    }
  });

  socket.on('typing-stop', (matchId) => {
    if (matchId && typeof matchId === 'string') {
      socket.to(matchId).emit('user-typing', {
        matchId,
        userId: socket.user.id,
        isTyping: false,
      });
    }
  });

  // Read receipts — spec §12 payload: { matchId, seenAt: ISO-8601 }.
  socket.on('mark-seen', async (payload) => {
    try {
      // Accept either `{ matchId }` (spec) or a raw matchId string for back-compat.
      const matchId = typeof payload === 'string' ? payload : payload?.matchId;
      if (!matchId || typeof matchId !== 'string') return;

      const seenAt = await messageService.markSeen(matchId, socket.user.id);

      // Notify the OTHER user only — emit into the room with a server-side
      // broadcast (socket.to skips the sender).
      socket.to(matchId).emit('messages-seen', {
        matchId,
        seenAt: seenAt.toISOString(),
      });

      // Also push to the other user's personal room in case they aren't
      // currently in the chat room.
      const match = await Match.findById(matchId).select('users').lean();
      if (match) {
        match.users.forEach((u) => {
          if (u.toString() !== socket.user.id.toString()) {
            io.to(u.toString()).emit('messages-seen', {
              matchId,
              seenAt: seenAt.toISOString(),
            });
          }
        });
      }
    } catch (err) {
      logger.warn({ err: err.message }, 'mark-seen error');
    }
  });
};

module.exports = chatHandler;
