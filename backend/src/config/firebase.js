const admin = require('firebase-admin');
const config = require('./index');
const logger = require('../utils/logger');

let firebaseApp = null;

const initFirebase = () => {
  if (firebaseApp) return firebaseApp;

  try {
    // Prefer inline JSON (env-only secret stores like Zoho Catalyst AppSail);
    // fall back to a file path for local/dev and file-mount platforms.
    let serviceAccount = null;
    if (config.firebaseServiceAccountJson) {
      serviceAccount = JSON.parse(config.firebaseServiceAccountJson);
    } else if (config.firebaseServiceAccountPath) {
      // eslint-disable-next-line global-require, import/no-dynamic-require
      serviceAccount = require(config.firebaseServiceAccountPath);
    }

    if (serviceAccount) {
      firebaseApp = admin.initializeApp({
        credential: admin.credential.cert(serviceAccount),
      });
      logger.info('Firebase Admin initialized');
    } else {
      logger.warn('Firebase service account not set (path/JSON), push notifications disabled');
    }
  } catch (err) {
    logger.warn('Firebase init failed, push notifications disabled:', err.message);
  }

  return firebaseApp;
};

module.exports = { initFirebase, admin };
