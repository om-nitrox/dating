const { admin } = require('../config/firebase');
const User = require('../models/User');
const logger = require('../utils/logger');

const MAX_RETRIES = 2;
const RETRY_DELAY_MS = 1000;

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

/**
 * Send push notification to all registered devices for a user.
 * Stale/invalid tokens are automatically pruned from the fcmTokens array.
 */
const sendPush = async (userId, title, body, data = {}, retries = 0) => {
  try {
    const user = await User.findById(userId).select('fcmTokens');

    if (!user || !user.fcmTokens || user.fcmTokens.length === 0) return;

    if (!admin.apps?.length) {
      logger.debug('Firebase not initialized, skipping push notification');
      return;
    }

    const tokens = user.fcmTokens.map((t) => t.token);

    const message = {
      notification: { title, body },
      data: { ...data, click_action: 'FLUTTER_NOTIFICATION_CLICK' },
      android: {
        priority: 'high',
        notification: { channelId: 'reverse_match_default' },
      },
      apns: {
        payload: { aps: { sound: 'default', badge: 1 } },
      },
    };

    const response = await admin.messaging().sendEachForMulticast({
      tokens,
      ...message,
    });

    // Prune stale tokens that are no longer registered
    const staleTokens = [];
    response.responses.forEach((resp, idx) => {
      if (
        !resp.success
        && (resp.error?.code === 'messaging/invalid-registration-token'
          || resp.error?.code === 'messaging/registration-token-not-registered')
      ) {
        staleTokens.push(tokens[idx]);
      }
    });

    if (staleTokens.length > 0) {
      await User.findByIdAndUpdate(userId, {
        $pull: { fcmTokens: { token: { $in: staleTokens } } },
      });
      logger.debug({ userId, count: staleTokens.length }, 'Pruned stale FCM tokens');
    }

    logger.debug({ userId, title, successCount: response.successCount }, 'Push sent');
  } catch (err) {
    if (retries < MAX_RETRIES) {
      logger.debug({ userId, retries: retries + 1, err: err.message }, 'Retrying push notification');
      await sleep(RETRY_DELAY_MS * (retries + 1));
      return sendPush(userId, title, body, data, retries + 1);
    }
    logger.warn({ userId, err: err.message }, 'Push notification failed after retries');
  }
};

/**
 * Upsert an FCM token for a specific device. Called on login/refresh.
 */
const upsertFcmToken = async (userId, token, deviceId) => {
  if (!token || !deviceId) return;

  await User.findByIdAndUpdate(userId, {
    $pull: { fcmTokens: { deviceId } },
  });

  await User.findByIdAndUpdate(userId, {
    $push: {
      fcmTokens: {
        $each: [{ token, deviceId, addedAt: new Date() }],
        $slice: -10,
      },
    },
  });
};

/**
 * Remove FCM token for a specific device. Called on logout.
 */
const removeFcmToken = async (userId, deviceId) => {
  if (!deviceId) return;
  await User.findByIdAndUpdate(userId, {
    $pull: { fcmTokens: { deviceId } },
  });
};

module.exports = { sendPush, upsertFcmToken, removeFcmToken };
