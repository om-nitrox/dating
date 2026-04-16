const admin = require('firebase-admin');
const config = require('./index');
const logger = require('../utils/logger');

let firebaseApp = null;

const initFirebase = () => {
  if (firebaseApp) return firebaseApp;

  try {
    if (config.firebaseServiceAccountPath) {
      const serviceAccount = require(config.firebaseServiceAccountPath);
      firebaseApp = admin.initializeApp({
        credential: admin.credential.cert(serviceAccount),
      });
      logger.info('Firebase Admin initialized');
    } else {
      logger.warn('Firebase service account path not set, push notifications disabled');
    }
  } catch (err) {
    logger.warn('Firebase init failed, push notifications disabled:', err.message);
  }

  return firebaseApp;
};

module.exports = { initFirebase, admin };
