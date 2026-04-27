const cron = require('node-cron');
const User = require('../models/User');
const logger = require('../utils/logger');

const BATCH_SIZE = 5000;

const initCronJobs = () => {
  // Run daily at midnight UTC — increment daysWithoutMatch for all active males (batched)
  cron.schedule('0 0 * * *', async () => {
    try {
      let totalModified = 0;
      let hasMore = true;
      let lastId = null;

      while (hasMore) {
        const query = {
          gender: 'male',
          isActive: true,
          isProfileComplete: true,
        };

        if (lastId) {
          query._id = { $gt: lastId };
        }

        const users = await User.find(query)
          .select('_id')
          .sort({ _id: 1 })
          .limit(BATCH_SIZE)
          .lean();

        if (users.length === 0) {
          hasMore = false;
          break;
        }

        const ids = users.map((u) => u._id);
        const result = await User.updateMany(
          { _id: { $in: ids } },
          { $inc: { daysWithoutMatch: 1 } },
        );

        totalModified += result.modifiedCount;
        lastId = ids[ids.length - 1];

        if (users.length < BATCH_SIZE) {
          hasMore = false;
        }
      }

      logger.info({ totalModified }, 'Daily boost job completed');
    } catch (err) {
      logger.error({ err: err.message }, 'Daily boost job failed');
    }
  });

  // Run hourly — clear expired paid boosts
  cron.schedule('0 * * * *', async () => {
    try {
      const result = await User.updateMany(
        {
          boostLevel: { $ne: 'none' },
          boostExpiry: { $lt: new Date() },
        },
        { boostLevel: 'none', boostExpiry: null },
      );
      if (result.modifiedCount > 0) {
        logger.info({ count: result.modifiedCount }, 'Cleared expired boosts');
      }
    } catch (err) {
      logger.error({ err: err.message }, 'Clear expired boosts job failed');
    }
  });

  logger.info('Cron jobs initialized');
};

module.exports = initCronJobs;
