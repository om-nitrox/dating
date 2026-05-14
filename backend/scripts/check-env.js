#!/usr/bin/env node
// Phase 1.6: standalone env-var validator for CI / pre-deploy sanity checks.
/**
 * Reads `.env` (and process.env), runs `validateConfig`, and prints a
 * structured report. Exit codes:
 *
 *   0 — Validation passed; if NODE_ENV != production, prints a warning for
 *       each missing-required-in-prod var but does NOT fail.
 *   1 — Always-required var missing OR schema parse error.
 *   2 — Production-only required var missing AND NODE_ENV=production.
 *
 * Usage:
 *   npm run check:env
 *   NODE_ENV=production npm run check:env
 */

const path = require('path');
const dotenv = require('dotenv');

// Load .env first — `validateConfig` reads process.env.
dotenv.config({ path: path.join(__dirname, '..', '.env') });

// Require the config module via its `validateConfig` export. We CANNOT
// require the default export because that would also boot the runtime
// validator and potentially process.exit(1) under us, swallowing the report.
//
// Workaround: re-require the schema directly. We do this by isolating
// `validateConfig` behind a lazy `require()` inside a try/catch — the runtime
// validator at module top-level will already have exited if the env was
// fatal, so by the time we reach this line the env is at least minimally
// valid. For the CI use case (we want to surface issues without exiting),
// we re-run validateConfig with `throwOnProdMissing: false`.

let validateConfig;
try {
  // The config module exits on failure. To avoid that for CI dry runs we
  // run a child process check via a fresh process.env snapshot below. But
  // for the happy path we can simply call the exported helper.
  // eslint-disable-next-line global-require
  ({ validateConfig } = require('../src/config'));
} catch (err) {
  // eslint-disable-next-line no-console
  console.error(`check:env failed to load config module: ${err.message}`);
  process.exit(1);
}

let report;
try {
  report = validateConfig(process.env, { throwOnProdMissing: false });
} catch (err) {
  // eslint-disable-next-line no-console
  console.error(`Validation failed: ${err.message}`);
  process.exit(1);
}

const env = report.parsed.NODE_ENV;
const missing = report.prodMissing;

// eslint-disable-next-line no-console
console.log(JSON.stringify({
  ok: missing.length === 0 || env !== 'production',
  nodeEnv: env,
  missingProdRequired: missing,
  warnings: report.warnings,
}, null, 2));

if (env === 'production' && missing.length > 0) {
  // eslint-disable-next-line no-console
  console.error(`PRODUCTION boot would crash: ${missing.length} required env var(s) missing.`);
  process.exit(2);
}

process.exit(0);
