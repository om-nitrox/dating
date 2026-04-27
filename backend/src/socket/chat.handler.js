const messageService = require('../services/message.service');
const Match = require('../models/Match');
const logger = require('../utils/logger');

const MAX_MESSAGE_LENGTH = 2000;

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

  // Send a message — with validation
  socket.on('send-message', async ({ matchId, text }) => {
    try {
      // Input validation
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
        return socket.emit('error', { message: `Message too long (max ${MAX_MESSAGE_LENGTH} characters)` });
      }

      const message = await messageService.sendMessage(
        matchId,
        socket.user.id,
        trimmed,
      );

      // Broadcast to everyone in the room (including sender for confirmation)
      io.to(matchId).emit('new-message', message);
    } catch (err) {
      socket.emit('error', { message: err.message });
    }
  });

  // Typing indicator
  socket.on('typing-start', (matchId) => {
    if (matchId && typeof matchId === 'string') {
      socket.to(matchId).emit('user-typing', {
        userId: socket.user.id,
        matchId,
      });
    }
  });

  socket.on('typing-stop', (matchId) => {
    if (matchId && typeof matchId === 'string') {
      socket.to(matchId).emit('user-stopped-typing', {
        userId: socket.user.id,
        matchId,
      });
    }
  });

  // Read receipts
  socket.on('mark-seen', async ({ matchId }) => {
    try {
      if (!matchId || typeof matchId !== 'string') return;

      await messageService.markSeen(matchId, socket.user.id);
      socket.to(matchId).emit('messages-seen', {
        userId: socket.user.id,
        matchId,
      });
    } catch (err) {
      logger.warn({ err: err.message }, 'mark-seen error');
    }
  });
};

module.exports = chatHandler;
