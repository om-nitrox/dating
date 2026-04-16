const mongoose = require('mongoose');
const config = require('./index');
const logger = require('../utils/logger');

const connectDB = async () => {
  try {
    const conn = await mongoose.connect(config.mongoUri, {
      // Connection pool for 1500 concurrent users
      maxPoolSize: config.nodeEnv === 'production' ? 100 : 10,
      minPoolSize: config.nodeEnv === 'production' ? 20 : 2,
      socketTimeoutMS: 45000,
      serverSelectionTimeoutMS: 10000,
      // Prevent slow queries from holding connections
      maxIdleTimeMS: 30000,
    });
    logger.info({ host: conn.connection.host }, 'MongoDB connected');
  } catch (err) {
    logger.error({ err: err.message }, 'MongoDB initial connection failed');
    throw err; // Let the caller handle it
  }

  mongoose.connection.on('error', (err) => {
    logger.error({ err: err.message }, 'MongoDB runtime error');
  });

  mongoose.connection.on('disconnected', () => {
    logger.warn('MongoDB disconnected — Mongoose will auto-reconnect');
  });

  mongoose.connection.on('reconnected', () => {
    logger.info('MongoDB reconnected');
  });
};

module.exports = connectDB;
