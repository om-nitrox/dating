const { Server } = require('socket.io');
const { createAdapter } = require('@socket.io/redis-adapter');
const { verifyAccessToken } = require('../utils/token');
const chatHandler = require('./chat.handler');
const config = require('../config');
const logger = require('../utils/logger');

const initSocket = (httpServer, redisClient) => {
  const io = new Server(httpServer, {
    cors: {
      origin: config.nodeEnv === 'development'
        ? '*'
        : config.corsOrigins,
      methods: ['GET', 'POST'],
    },
    // Limit payload size to prevent abuse
    maxHttpBufferSize: config.socketMaxPayloadBytes,
    // Ping timeout
    pingTimeout: 20000,
    pingInterval: 25000,
  });

  // Use Redis adapter for multi-instance support (if Redis is available)
  if (redisClient && redisClient.status === 'ready') {
    try {
      const pubClient = redisClient.duplicate();
      const subClient = redisClient.duplicate();
      io.adapter(createAdapter(pubClient, subClient));
      logger.info('Socket.IO Redis adapter enabled');
    } catch (err) {
      logger.warn({ err: err.message }, 'Socket.IO Redis adapter failed, using in-memory');
    }
  }

  // JWT authentication middleware
  io.use((socket, next) => {
    const token = socket.handshake.auth?.token;

    if (!token) {
      return next(new Error('Authentication required'));
    }

    try {
      const decoded = verifyAccessToken(token);
      socket.user = { id: decoded.id, gender: decoded.gender };
      next();
    } catch {
      next(new Error('Invalid token'));
    }
  });

  io.on('connection', (socket) => {
    const userId = socket.user.id;

    // Personal room for targeted events (works across instances with Redis adapter)
    socket.join(userId);

    logger.debug({ userId }, 'User connected via socket');

    // Set up chat handlers
    chatHandler(io, socket);

    socket.on('disconnect', () => {
      logger.debug({ userId }, 'User disconnected from socket');
    });

    // Error handling per socket
    socket.on('error', (err) => {
      logger.warn({ userId, err: err.message }, 'Socket error');
    });
  });

  return io;
};

module.exports = initSocket;
