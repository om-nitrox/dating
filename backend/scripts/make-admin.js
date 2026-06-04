/* eslint-disable no-console */
/**
 * Promote (or demote) a user to admin by email.
 *
 * Admins see ONLY the verification queue in the app — they review and
 * approve/reject girls' profiles. There is no UI to grant the admin role,
 * so use this script once to bootstrap your admin account.
 *
 * Usage:
 *   node scripts/make-admin.js <email>            # promote to admin
 *   node scripts/make-admin.js <email> --revoke   # demote back to user
 */

const mongoose = require('mongoose');
const dotenv = require('dotenv');
const path = require('path');

dotenv.config({ path: path.join(__dirname, '..', '.env') });

const User = require('../src/models/User');

const run = async () => {
  const email = (process.argv[2] || '').trim().toLowerCase();
  const revoke = process.argv.includes('--revoke');

  if (!email) {
    console.error('Usage: node scripts/make-admin.js <email> [--revoke]');
    process.exit(1);
  }

  const uri = process.env.MONGO_URI;
  if (!uri) {
    console.error('MONGO_URI is not set in backend/.env');
    process.exit(1);
  }

  await mongoose.connect(uri);

  const role = revoke ? 'user' : 'admin';
  const user = await User.findOneAndUpdate(
    { email },
    { $set: { role } },
    { new: true },
  ).select('email role');

  if (!user) {
    console.error(`No user found with email: ${email}`);
    await mongoose.disconnect();
    process.exit(1);
  }

  console.log(`✓ ${user.email} is now role="${user.role}"`);
  await mongoose.disconnect();
  process.exit(0);
};

run().catch((err) => {
  console.error('Failed:', err.message);
  process.exit(1);
});
