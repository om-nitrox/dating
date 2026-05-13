/**
 * One-off pre-deploy check: find duplicate Match docs sharing the same pair of
 * users (regardless of insertion order). MUST be clean before the unique pair
 * index can be built on the live collection.
 *
 * Usage:
 *   node scripts/check-duplicate-matches.js
 *
 * Reads MONGO_URI from .env. Exits 0 if no duplicates, 1 otherwise (so the
 * script is safe to use in a CI gate).
 */

require('dotenv').config();
const mongoose = require('mongoose');

const run = async () => {
  if (!process.env.MONGO_URI) {
    console.error('MONGO_URI missing in env');
    process.exit(2);
  }

  await mongoose.connect(process.env.MONGO_URI);

  const Match = mongoose.connection.collection('matches');

  // Group by sorted user-pair so [u1, u2] and [u2, u1] collapse.
  const duplicates = await Match.aggregate([
    {
      $project: {
        _id: 1,
        sortedUsers: {
          $cond: [
            { $lte: [{ $arrayElemAt: ['$users', 0] }, { $arrayElemAt: ['$users', 1] }] },
            ['$users'],
            [[{ $arrayElemAt: ['$users', 1] }, { $arrayElemAt: ['$users', 0] }]],
          ],
        },
        users: 1,
      },
    },
    {
      $group: {
        _id: { $arrayElemAt: ['$sortedUsers', 0] },
        ids: { $push: '$_id' },
        count: { $sum: 1 },
      },
    },
    { $match: { count: { $gt: 1 } } },
  ]).toArray();

  if (duplicates.length === 0) {
    console.log('No duplicate match pairs found — safe to apply unique pair index.');
    await mongoose.disconnect();
    process.exit(0);
  }

  console.error(`Found ${duplicates.length} duplicated pair(s):`);
  duplicates.slice(0, 25).forEach((d) => {
    console.error(`  users=${JSON.stringify(d._id)} ids=${d.ids.join(',')}`);
  });
  await mongoose.disconnect();
  process.exit(1);
};

run().catch((err) => {
  console.error(err);
  process.exit(2);
});
