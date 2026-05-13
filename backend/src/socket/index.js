const { Server } = require('socket.io');
const { createAdapter } = require('@socket.io/redis-adapter');
const { randomUUID } = require('crypto');
const { verifyAccessToken } = require('../utils/token');
const { getRedis } = require('../config/redis');
const User = require('../models/User');
const chatHandler = require('./chat.handler');
const config = require('../config');
const logger = require('../utils/logger');
const { socketConnectionsActive } = require('../observability/metrics');

/**
 * Extract a bearer token from either:
 *   1. `socket.handshake.auth.token` (Socket.IO client default)
 *   2. `Authorization: Bearer <token>` header (spec §12 fallback)
 */
const extractToken = (socket) => {
  const fromAuth = socket.handshake?.auth?.token;
  if (fromAuth) return fromAuth;
  const header = socket.handshake?.headers?.authorization;
  if (header && header.startsWith('Bearer ')) return header.slice(7);
  return null;
};

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
  io.use(async (socket, next) => {
    const token = extractToken(socket);

    if (!token) {
      return next(new Error('Authentication required'));
    }

    let decoded;
    try {
      decoded = verifyAccessToken(token);
    } catch {
      return next(new Error('Invalid token'));
    }

    // Mirror HTTP auth middleware: check blacklist + banned set in Redis
    // before letting the socket join.  On Redis failure we fall back to a
    // DB ban check so we don't fail open.
    try {
      const redis = getRedis();
      if (decoded.jti) {
        const blacklisted = await redis.get(`blacklist:${decoded.jti}`);
        if (blacklisted) return next(new Error('Token has been revoked'));
      }
      const banned = await redis.get(`banned:${decoded.id}`);
      if (banned) return next(new Error('Account suspended'));
    } catch (_) {
      // Redis unavailable — fall through to DB check.
    }

    try {
      const u = await User.findById(decoded.id, { banned: 1 }).lean();
      if (u && u.banned) return next(new Error('Account suspended'));
    } catch (err) {
      logger.warn({ err: err.message }, 'Socket ban-check DB failure');
    }

    socket.user = { id: decoded.id, gender: decoded.gender };
    return next();
  });

  io.on('connection', (socket) => {
    const userId = socket.user.id;

    // Phase 0.5: assign a `connection_id` to every socket so every log line
    // and Sentry event raised during this connection is correlatable to the
    // exact socket instance. This is distinct from the HTTP `req.id`
    // (sockets are long-lived; an HTTP req is a single round-trip).
    const connectionId = randomUUID();
    socket.data.connectionId = connectionId;
    socket.data.log = logger.child({ connection_id: connectionId, userId });

    // Personal room for targeted events (works across instances with Redis adapter)
    socket.join(userId);

    // Phase 0.9: track active connection count (gauge).
    socketConnectionsActive.inc();

    // Phase 0.9: structured-log convention — `socket.*` events.
    socket.data.log.info({ event: 'socket.connected', userId }, 'socket connected');

    // Set up chat handlers
    chatHandler(io, socket);

    socket.on('disconnect', () => {
      socketConnectionsActive.dec();
      socket.data.log.info({ event: 'socket.disconnected', userId }, 'socket disconnected');
    });

    // Error handling per socket
    socket.on('error', (err) => {
      socket.data.log.warn({ err: err.message }, 'Socket error');
    });
  });

  return io;
};

module.exports = initSocket;
