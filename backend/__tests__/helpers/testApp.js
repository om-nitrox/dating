/**
 * Creates a self-contained test app with in-memory MongoDB and mocked Redis.
 * Import this in integration tests instead of app.js directly.
 */

// Set env vars before ANY module import that reads process.env
process.env.MONGO_URI = 'mongodb://localhost:27017/test_placeholder';
process.env.JWT_ACCESS_SECRET = 'test-access-secret-32-chars-long!!';
process.env.JWT_REFRESH_SECRET = 'test-refresh-secret-32-chars-long!';
process.env.NODE_ENV = 'test';

// Mock Redis so tests don't need a running Redis instance
// Use status 'connecting' so createStore() skips Redis and falls back to in-memory rate limiting.
const mockRedis = {
  status: 'connecting',
  get: jest.fn().mockResolvedValue(null),
  set: jest.fn().mockResolvedValue('OK'),
  del: jest.fn().mockResolvedValue(1),
  scan: jest.fn().mockResolvedValue(['0', []]),
  call: jest.fn().mockResolvedValue(null),
  ping: jest.fn().mockResolvedValue('PONG'),
  on: jest.fn(),
  connect: jest.fn().mockResolvedValue(undefined),
};

jest.mock('../../src/config/redis', () => ({
  connectRedis: () => mockRedis,
  getRedis: () => mockRedis,
}));

// Mock Firebase Admin (not needed for most integration tests)
jest.mock('../../src/config/firebase', () => ({
  admin: {
    apps: [],
    messaging: () => ({
      sendEachForMulticast: jest.fn().mockResolvedValue({ successCount: 0, responses: [] }),
    }),
  },
}));

const { MongoMemoryServer } = require('mongodb-memory-server');
const mongoose = require('mongoose');
const app = require('../../src/app');

let mongoServer;

const startTestApp = async () => {
  mongoServer = await MongoMemoryServer.create();
  const uri = mongoServer.getUri();
  if (mongoose.connection.readyState === 0) {
    await mongoose.connect(uri);
  }
  return app;
};

const stopTestApp = async () => {
  await mongoose.disconnect();
  if (mongoServer) await mongoServer.stop();
};

const clearDB = async () => {
  const collections = mongoose.connection.collections;
  await Promise.all(Object.values(collections).map((col) => col.deleteMany({})));
};

module.exports = { startTestApp, stopTestApp, clearDB, mockRedis };
