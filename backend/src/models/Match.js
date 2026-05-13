const mongoose = require('mongoose');

const matchSchema = new mongoose.Schema(
  {
    users: [
      {
        type: mongoose.Schema.Types.ObjectId,
        ref: 'User',
        required: true,
      },
    ],
  },
  {
    timestamps: true,
  },
);

// Sort participant ObjectIds before persisting so the unique compound index
// below can enforce pair uniqueness regardless of who liked first. We MUST
// have exactly 2 participants per the schema usage; if someone ever introduces
// group matches, revisit this hook. (Mongoose 8+ pre-save hooks return a
// promise — no `next` callback.)
matchSchema.pre('save', async function sortUsers() {
  if (Array.isArray(this.users) && this.users.length === 2) {
    const a = this.users[0].toString();
    const b = this.users[1].toString();
    if (a > b) this.users = [this.users[1], this.users[0]];
  }
});

// Generic "either participant" lookup index (used by getMatches / deleteAccount).
matchSchema.index({ users: 1 });

// Unique pair invariant. `users.0` and `users.1` indexed together means
// inserting `[u1, u2]` twice (after sort) violates the unique constraint.
matchSchema.index(
  { 'users.0': 1, 'users.1': 1 },
  { unique: true, name: 'uniq_user_pair' },
);

module.exports = mongoose.model('Match', matchSchema);
