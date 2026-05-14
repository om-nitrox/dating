// Phase 1.5: migrate-mongo configuration.
/**
 * migrate-mongo wiring.
 *
 * Reads `config.mongoUri` so migrations target the SAME connection string
 * the api / worker use — no second `MONGO_URI` to keep in sync.
 *
 * Conventions:
 *   - Migrations live in `backend/migrations/` (sibling to this file).
 *   - File naming is the migrate-mongo default: `<timestamp>-<slug>.js`.
 *   - The `changelog` collection name matches what migrate-mongo expects
 *     by default — kept explicit so it's discoverable from grep.
 *
 * Run:
 *   npm run migrate            # apply all pending
 *   npm run migrate:status     # list applied / pending
 *   npm run migrate:down       # roll back ONE
 *   npm run migrate:create  -- <slug>
 */

const path = require('path');

// Load env so MONGO_URI resolves the same way it does for the app boot. We
// require the config module rather than the raw env so the validation
// pipeline runs identically — a malformed env still fails fast for
// migrations.
//
// IMPORTANT: this file is invoked by the migrate-mongo CLI from arbitrary
// cwds (CI, local, container). Use an absolute path resolution.
require('dotenv').config({ path: path.join(__dirname, '.env') });
const config = require('./src/config');

// Derive a database name from the URI. For Atlas SRV URIs without an
// explicit `/<db>` segment we fall back to the literal "reverse_match"
// (matching the default in BACKEND_API.md).
const deriveDatabaseName = (uri) => {
  try {
    // Strip query string then take the last path segment.
    const noQs = uri.split('?')[0];
    const m = noQs.match(/\/(?<db>[A-Za-z0-9._-]+)\/?$/);
    if (m && m.groups && m.groups.db) return m.groups.db;
  } catch (_) { /* fall through */ }
  return 'reverse_match';
};

module.exports = {
  mongodb: {
    url: config.mongoUri,
    databaseName: deriveDatabaseName(config.mongoUri),
    options: {
      // Modern driver — no deprecation warnings.
    },
  },
  migrationsDir: path.join(__dirname, 'migrations'),
  changelogCollectionName: 'changelog',
  migrationFileExtension: '.js',
  useFileHash: false,
  moduleSystem: 'commonjs',
};
