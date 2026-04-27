const http = require('http');
const { Server } = require('socket.io');
const { io: ioc } = require('socket.io-client');
const { MongoMemoryServer } = require('mongodb-memory-server');
const mongoose = require('mongoose');

// Set env vars before importing anything from src/
process.env.JWT_ACCESS_SECRET = 'test-access-secret-32-chars-long!!';
process.env.JWT_REFRESH_SECRET = 'test-refresh-secret-32-chars-long!';
process.env.MONGO_URI = 'mongodb://localhost:27017/test_socket';
process.env.NODE_ENV = 'test';

const mockRedis = {
  status: 'ready',
  get: jest.fn().mockResolvedValue(null),
  set: jest.fn().mockResolvedValue('OK'),
  del: jest.fn().mockResolvedValue(1),
  scan: jest.fn().mockResolvedValue(['0', []]),
  call: jest.fn(),
  on: jest.fn(),
  connect: jest.fn(),
  duplicate: jest.fn().mockReturnThis(),
  subscribe: jest.fn(),
  publish: jest.fn(),
};

jest.mock('../../src/config/redis', () => ({
  connectRedis: () => mockRedis,
  getRedis: () => mockRedis,
}));

jest.mock('@socket.io/redis-adapter', () => ({
  createAdapter: jest.fn().mockReturnValue(undefined),
}));

const { signAccessToken } = require('../../src/utils/token');
const User = require('../../src/models/User');
const Match = require('../../src/models/Match');
const Message = require('../../src/models/Message');

let mongoServer;
let httpServer;
let io;
let port;

const createSocketServer = () => {
  const chatHandler = require('../../src/socket/chat.handler');
  const auth = require('../../src/middleware/auth.middleware');

  const expressApp = require('express')();
  httpServer = http.createServer(expressApp);

  io = new Server(httpServer, { cors: { origin: '*' } });

  io.use(async (socket, next) => {
    const token = socket.handshake.auth?.token;
    if (!token) return next(new Error('No token'));
    try {
      const jwt = require('jsonwebtoken');
      const decoded = jwt.verify(token, process.env.JWT_ACCESS_SECRET);
      socket.user = { id: decoded.id, gender: decoded.gender };
      socket.join(decoded.id);
      next();
    } catch {
      next(new Error('Invalid token'));
    }
  });

  io.on('connection', (socket) => {
    chatHandler(io, socket);
  });

  return new Promise((resolve) => {
    httpServer.listen(0, () => {
      port = httpServer.address().port;
      resolve();
    });
  });
};

const connect = (token) =>
  new Promise((resolve, reject) => {
    const client = ioc(`http://localhost:${port}`, {
      auth: { token },
      transports: ['websocket'],
    });
    client.on('connect', () => resolve(client));
    client.on('connect_error', reject);
  });

beforeAll(async () => {
  mongoServer = await MongoMemoryServer.create();
  await mongoose.connect(mongoServer.getUri());
  await createSocketServer();
});

afterAll(async () => {
  io.close();
  httpServer.close();
  await mongoose.disconnect();
  await mongoServer.stop();
});

afterEach(async () => {
  const collections = mongoose.connection.collections;
  await Promise.all(Object.values(collections).map((col) => col.deleteMany({})));
});

describe('Socket.IO authentication', () => {
  it('connects with valid JWT', async () => {
    const user = await User.create({ email: 'socket@test.com', dob: new Date('1995-01-01') });
    const token = signAccessToken(user._id, user.gender);

    const client = await connect(token);
    expect(client.connected).toBe(true);
    client.disconnect();
  });

  it('disconnects with invalid JWT', (done) => {
    const client = ioc(`http://localhost:${port}`, {
      auth: { token: 'bad-token' },
      transports: ['websocket'],
    });

    client.on('connect_error', (err) => {
      expect(err.message).toBeTruthy();
      client.disconnect();
      done();
    });
  });
});

describe('Socket.IO chat events', () => {
  let user1;
  let user2;
  let match;
  let client1;
  let client2;

  beforeEach(async () => {
    user1 = await User.create({ email: 'u1@test.com', dob: new Date('1995-01-01') });
    user2 = await User.create({ email: 'u2@test.com', dob: new Date('1995-01-01') });
    match = await Match.create({ users: [user1._id, user2._id] });

    client1 = await connect(signAccessToken(user1._id, user1.gender));
    client2 = await connect(signAccessToken(user2._id, user2.gender));

    // Both clients join the match room
    await Promise.all([
      new Promise((res) => { client1.emit('join-room', match._id.toString()); setTimeout(res, 50); }),
      new Promise((res) => { client2.emit('join-room', match._id.toString()); setTimeout(res, 50); }),
    ]);
  });

  afterEach(() => {
    client1.disconnect();
    client2.disconnect();
  });

  it('send-message — other user in room receives new-message', (done) => {
    client2.on('new-message', (msg) => {
      expect(msg.text).toBe('Hello!');
      done();
    });

    client1.emit('send-message', { matchId: match._id.toString(), text: 'Hello!' });
  });

  it('typing event — other user receives user-typing', (done) => {
    client2.on('user-typing', (data) => {
      expect(data.userId).toBe(user1._id.toString());
      done();
    });

    client1.emit('typing-start', match._id.toString());
  });

  it('mark-seen event — seen status persisted in DB', (done) => {
    Message.create({
      matchId: match._id,
      sender: user1._id,
      text: 'Read me',
      seen: false,
    }).then((msg) => {
      client2.emit('mark-seen', { matchId: match._id.toString() });

      setTimeout(async () => {
        const updated = await Message.findById(msg._id);
        expect(updated.seen).toBe(true);
        expect(updated.seenAt).toBeDefined();
        done();
      }, 200);
    });
  });

  it('mark-seen event — messages-seen emitted to other user', (done) => {
    client1.on('messages-seen', (data) => {
      expect(data.userId).toBe(user2._id.toString());
      done();
    });

    client2.emit('mark-seen', { matchId: match._id.toString() });
  });
});
