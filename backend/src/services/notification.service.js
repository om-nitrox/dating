const { admin } = require('../config/firebase');
const User = require('../models/User');
const logger = require('../utils/logger');

const MAX_RETRIES = 2;
const RETRY_DELAY_MS = 1000;

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

/**
 * Send push notification with retry logic.
 */
const sendPush = async (userId, title, body, data = {}, retries = 0) => {
  try {
    const user = await User.findById(userId).select('fcmToken');

    if (!user?.fcmToken) return;

    if (!admin.apps?.length) {
      logger.debug('Firebase not initialized, skipping push notification');
      return;
    }

    await admin.messaging().send({
      token: user.fcmToken,
      notification: { title, body },
      data: { ...data, click_action: 'FLUTTER_NOTIFICATION_CLICK' },
      android: {
        priority: 'high',
        notification: { channelId: 'reverse_match_default' },
      },
      apns: {
        payload: {
          aps: { sound: 'default', badge: 1 },
        },
      },
    });

    logger.debug({ userId, title }, 'Push sent');
  } catch (err) {
    // Token is invalid or expired — clear it
    if (
      err.code === 'messaging/invalid-registration-token' ||
      err.code === 'messaging/registration-token-not-registered'
    ) {
      await User.findByIdAndUpdate(userId, { fcmToken: null });
      logger.debug({ userId }, 'Cleared stale FCM token');
      return;
    }

    // Retry on transient errors
    if (retries < MAX_RETRIES) {
      logger.debug({ userId, retries: retries + 1, err: err.message }, 'Retrying push notification');
      await sleep(RETRY_DELAY_MS * (retries + 1));
      return sendPush(userId, title, body, data, retries + 1);
    }

    logger.warn({ userId, err: err.message }, 'Push notification failed after retries');
  }
};

module.exports = { sendPush };
