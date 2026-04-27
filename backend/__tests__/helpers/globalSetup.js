// Set required env vars before any module is loaded
process.env.MONGO_URI = 'mongodb://localhost:27017/test';
process.env.JWT_ACCESS_SECRET = 'test-access-secret-32-chars-long!!';
process.env.JWT_REFRESH_SECRET = 'test-refresh-secret-32-chars-long!';
process.env.NODE_ENV = 'test';
process.env.REDIS_URL = 'redis://localhost:6379';

module.exports = async () => {};
