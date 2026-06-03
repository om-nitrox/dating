// Phase 1.6: zod-validated environment configuration.
/**
 * Boot-time environment validation with zod.
 *
 * Why this exists (Phase 1.6):
 *   The previous loader threw on missing `MONGO_URI` / `JWT_*` but accepted
 *   silently undefined values for Stripe, Cloudinary, Firebase, CORS, etc.
 *   In production that meant the first request which actually NEEDS Stripe
 *   discovered the missing config at 500-time, well past the point where the
 *   crash could be caught by a deploy probe.
 *
 *   This module flips the contract:
 *     - In production: ALL required env vars are validated at boot. Any
 *       missing/invalid value causes a structured fatal log followed by
 *       `process.exit(1)` BEFORE we open a single port.
 *     - In dev/test: validation runs in "soft" mode. Missing-but-required-in-
 *       prod vars get a single WARN at boot so local development keeps
 *       working with a partial `.env`.
 *
 *   The `check:env` npm script (see package.json) calls `validateConfig()`
 *   directly and exits non-zero on failure — handy for CI sanity checks.
 *
 * Required-in-prod, optional-in-dev:
 *   REDIS_URL, CLOUDINARY_*, STRIPE_*, GOOGLE_CLIENT_ID, SMTP_*,
 *   FIREBASE_SERVICE_ACCOUNT_PATH, OTP_PEPPER, APP_BASE_URL, CORS_ORIGINS.
 *
 * Always-required (any env):
 *   MONGO_URI, JWT_ACCESS_SECRET, JWT_REFRESH_SECRET.
 */

const dotenv = require('dotenv');
const path = require('path');
const { z } = require('zod');

// Load .env once. In production deploys, env is typically injected by the
// platform (ECS task def, k8s secrets, Zoho Catalyst env_variables) — `.env`
// is a no-op there.
dotenv.config({ path: path.join(__dirname, '../../.env') });

// Zoho Catalyst AppSail injects the port to bind on via
// `X_ZOHO_CATALYST_LISTEN_PORT` rather than `PORT`. Coalesce it into `PORT`
// before validation so `config.port` (and `server.js`) bind correctly on
// AppSail while still honoring an explicit `PORT` elsewhere.
if (process.env.X_ZOHO_CATALYST_LISTEN_PORT) {
  process.env.PORT = process.env.X_ZOHO_CATALYST_LISTEN_PORT;
}

// -------- helpers --------

const nonEmptyString = z
  .string()
  .trim()
  .min(1, 'must be a non-empty string');

const optionalString = z.string().trim().optional();

// Comma-separated origin list -> string[]. Empty input becomes [].
const csvList = z
  .string()
  .transform((s) => s.split(',').map((p) => p.trim()).filter(Boolean));

// Coerced positive integer (defaults applied by caller via `.default(...)`).
const positiveInt = z.coerce.number().int().positive();

// `'true'|'false'|'1'|'0'` -> boolean. Defaults applied by caller.
const boolString = z
  .union([z.boolean(), z.string()])
  .transform((v) => {
    if (typeof v === 'boolean') return v;
    const s = String(v).toLowerCase().trim();
    return !(s === 'false' || s === '0' || s === '');
  });

// JWT expiry strings like "15m" / "7d" / "900". Returns the raw string;
// `jwtAccessExpirySeconds` is computed separately.
const jwtExpiry = z
  .string()
  .regex(/^(\d+)([smhd])?$/i, 'must look like "15m", "7d", or a raw seconds count');

// -------- schema --------

// Two-pass design: a permissive base schema parses ALL fields, then
// `enforceProdRequired()` raises any field that's optional-but-required-in-prod
// to an error in production. This lets dev keep running without Stripe etc.

const baseSchema = z.object({
  // -------- core --------
  NODE_ENV: z
    .enum(['development', 'test', 'staging', 'production'])
    .default('development'),
  PORT: positiveInt.default(5000),

  // -------- always required --------
  MONGO_URI: nonEmptyString,
  JWT_ACCESS_SECRET: nonEmptyString.min(16, 'JWT_ACCESS_SECRET must be >= 16 chars'),
  JWT_REFRESH_SECRET: nonEmptyString.min(16, 'JWT_REFRESH_SECRET must be >= 16 chars'),
  JWT_ACCESS_EXPIRY: jwtExpiry.default('15m'),
  JWT_REFRESH_EXPIRY: jwtExpiry.default('7d'),

  // -------- prod-required (validated by enforceProdRequired) --------
  REDIS_URL: optionalString,
  CLOUDINARY_CLOUD_NAME: optionalString,
  CLOUDINARY_API_KEY: optionalString,
  CLOUDINARY_API_SECRET: optionalString,
  CLOUDINARY_MODERATION: optionalString,
  STRIPE_SECRET_KEY: optionalString,
  STRIPE_WEBHOOK_SECRET: optionalString,
  GOOGLE_CLIENT_ID: optionalString,
  SMTP_HOST: optionalString,
  SMTP_PORT: z.coerce.number().int().positive().optional(),
  SMTP_USER: optionalString,
  SMTP_PASS: optionalString,
  FIREBASE_SERVICE_ACCOUNT_PATH: optionalString,
  // Alternative to the file path for env-only secret stores (e.g. Zoho
  // Catalyst AppSail): the raw service-account JSON as a single string.
  FIREBASE_SERVICE_ACCOUNT_JSON: optionalString,
  OTP_PEPPER: optionalString,
  OTP_EXPIRY_MINUTES: z.coerce.number().int().positive().optional(),
  // Shared secret guarding the /internal/cron/* endpoints that Catalyst Cron
  // calls (sent as the `X-Cron-Secret` header). When unset, those endpoints
  // refuse to run.
  CRON_SECRET: optionalString,
  APP_BASE_URL: optionalString,
  APP_DEEP_LINK_SCHEME: optionalString,
  PRIVACY_POLICY_URL: optionalString,
  TERMS_OF_SERVICE_URL: optionalString,
  SUPPORT_EMAIL: optionalString,
  MIN_APP_VERSION: optionalString,
  CORS_ORIGINS: optionalString,
  SENTRY_DSN: optionalString,

  // -------- optional with defaults --------
  LIKE_RATE_LIMIT_WINDOW_MS: positiveInt.default(3600000),
  LIKE_RATE_LIMIT_MAX: positiveInt.default(100),
  MAX_REQUEST_BODY_SIZE: z.string().default('10mb'),
  SOCKET_MAX_PAYLOAD_BYTES: positiveInt.default(65536),
  MONGO_TRANSACTIONS_ENABLED: boolString.default('true'),
  REPORT_AUTO_SUSPEND_THRESHOLD: positiveInt.default(5),
  MAX_PHOTO_SIZE_BYTES: positiveInt.default(5 * 1024 * 1024),
  WORKER_METRICS_PORT: positiveInt.default(9091),
  BULLMQ_QUEUE_PREFIX: z.string().default('rm'),

  // Phase 1.4: idempotency cache TTL (seconds). 24h matches Stripe's
  // retry window and bounds Redis growth.
  IDEMPOTENCY_TTL_SECONDS: positiveInt.default(86400),
  // Phase 1.4: how long a retry blocks waiting for the in-flight
  // original request to finish before giving up with 409.
  IDEMPOTENCY_INFLIGHT_TIMEOUT_MS: positiveInt.default(8000),

  // Phase 1.2: media reaper cron (every N minutes).
  MEDIA_REAPER_INTERVAL_MS: positiveInt.default(5 * 60 * 1000),

  // -------- ML matchmaker microservice --------
  // Empty ML_SERVICE_URL disables the integration; idealMatch.service.js
  // then falls back to the legacy one-hot cosine encoder.
  ML_SERVICE_URL: optionalString,
  ML_SERVICE_API_KEY: optionalString,
  ML_SERVICE_TIMEOUT_MS: positiveInt.default(2500),
});

// Per Phase 1.6 brief — these are the env vars that MUST be set for a safe
// production boot. Each entry is a (key, friendly description) pair.
const PROD_REQUIRED = [
  ['REDIS_URL', 'Redis is the source of truth for rate limits, idempotency cache, and pub/sub.'],
  ['CLOUDINARY_CLOUD_NAME', 'Cloudinary CDN — required for any photo upload.'],
  ['CLOUDINARY_API_KEY', 'Cloudinary auth.'],
  ['CLOUDINARY_API_SECRET', 'Cloudinary auth.'],
  ['STRIPE_SECRET_KEY', 'Stripe payments — required to issue checkout sessions.'],
  ['STRIPE_WEBHOOK_SECRET', 'Stripe webhook signature verification — without it boost activation is spoofable.'],
  ['GOOGLE_CLIENT_ID', 'Google sign-in ID token verification.'],
  ['SMTP_HOST', 'Email transport for OTPs.'],
  ['SMTP_USER', 'Email transport for OTPs.'],
  ['SMTP_PASS', 'Email transport for OTPs.'],
  // Satisfied by EITHER the file path OR the inline JSON (env-only platforms).
  ['FIREBASE_SERVICE_ACCOUNT_PATH', 'Firebase Admin SDK — required for FCM push notifications. Provide FIREBASE_SERVICE_ACCOUNT_PATH (file) or FIREBASE_SERVICE_ACCOUNT_JSON (inline).', ['FIREBASE_SERVICE_ACCOUNT_JSON']],
  ['OTP_PEPPER', 'Dedicated HMAC key for OTP hash storage — without it OTP rows fall back to JWT_ACCESS_SECRET, coupling secret rotation.'],
  ['APP_BASE_URL', 'Public backend URL — used to build Stripe success/cancel URLs.'],
  ['CORS_ORIGINS', 'Comma-separated allow-list of browser origins. Without it production CORS rejects everything.'],
];

/**
 * Validate the raw process.env against the schema.
 *
 * @param {NodeJS.ProcessEnv} env  defaults to process.env
 * @param {{ throwOnProdMissing?: boolean }} opts
 * @returns {{ parsed: object, prodMissing: string[], warnings: string[] }}
 *   - `parsed`: the validated env object (with defaults applied)
 *   - `prodMissing`: env vars required-in-prod that are absent
 *   - `warnings`: human-readable strings describing each missing-in-prod entry
 */
const validateConfig = (env = process.env, opts = {}) => {
  const parseResult = baseSchema.safeParse(env);
  if (!parseResult.success) {
    const messages = parseResult.error.issues
      .map((issue) => {
        const issuePath = issue.path.length ? issue.path.join('.') : '(root)';
        return `${issuePath}: ${issue.message}`;
      });
    const err = new Error(
      `Environment validation failed (${messages.length} issue${messages.length === 1 ? '' : 's'}):\n  - ${messages.join('\n  - ')}`,
    );
    err.code = 'ENV_VALIDATION_FAILED';
    err.issues = parseResult.error.issues;
    throw err;
  }

  const parsed = parseResult.data;

  const isSet = (v) => !(v === undefined || v === null || v === '');

  const prodMissing = [];
  const warnings = [];
  for (const [key, desc, alternatives = []] of PROD_REQUIRED) {
    // A requirement is satisfied if the primary key OR any listed alternative
    // is set (e.g. Firebase: file path OR inline JSON).
    const satisfied = isSet(parsed[key]) || alternatives.some((alt) => isSet(parsed[alt]));
    if (!satisfied) {
      prodMissing.push(key);
      warnings.push(`${key} — ${desc}`);
    }
  }

  if (parsed.NODE_ENV === 'production' && prodMissing.length > 0 && opts.throwOnProdMissing !== false) {
    const err = new Error(
      `${prodMissing.length} environment variable(s) are required in production but not set:\n  - ${warnings.join('\n  - ')}`,
    );
    err.code = 'ENV_PROD_REQUIRED_MISSING';
    err.missing = prodMissing;
    throw err;
  }

  return { parsed, prodMissing, warnings };
};

// ----------------------------------------------------------------------
// Build the runtime `config` object from the validated env.
// ----------------------------------------------------------------------

let parsed;
let prodMissing = [];
let warnings = [];
try {
  ({ parsed, prodMissing, warnings } = validateConfig(process.env));
} catch (err) {
  // We can't use `utils/logger` here because logger may itself depend on
  // config (it doesn't today, but it could). Use stderr directly with a
  // structured payload so log aggregators can parse it.
  const payload = {
    level: 'fatal',
    event: 'config.invalid',
    code: err.code,
    msg: err.message,
    missing: err.missing || [],
  };
  // eslint-disable-next-line no-console
  console.error(JSON.stringify(payload));
  // Fail hard — DO NOT let the server boot into a broken state.
  process.exit(1);
}

// Dev/test soft warnings — visible at boot once.
if (parsed.NODE_ENV !== 'production' && warnings.length > 0) {
  // Keep this terse; the operator can grep for "config.devWarning".
  // eslint-disable-next-line no-console
  console.warn(
    JSON.stringify({
      level: 'warn',
      event: 'config.devWarning',
      msg: 'Some env vars are optional in dev but required in production.',
      missing: prodMissing,
    }),
  );
}

const parseJwtSeconds = (raw) => {
  const m = String(raw).match(/^(\d+)([smhd])?$/i);
  if (!m) return 900;
  const n = parseInt(m[1], 10);
  const unit = (m[2] || 's').toLowerCase();
  const factor = {
    s: 1, m: 60, h: 3600, d: 86400,
  }[unit] || 1;
  return n * factor;
};

const config = {
  port: parsed.PORT,
  nodeEnv: parsed.NODE_ENV,
  mongoUri: parsed.MONGO_URI,

  jwtAccessSecret: parsed.JWT_ACCESS_SECRET,
  jwtRefreshSecret: parsed.JWT_REFRESH_SECRET,
  jwtAccessExpiry: parsed.JWT_ACCESS_EXPIRY,
  jwtRefreshExpiry: parsed.JWT_REFRESH_EXPIRY,
  jwtAccessExpirySeconds: parseJwtSeconds(parsed.JWT_ACCESS_EXPIRY),

  googleClientId: parsed.GOOGLE_CLIENT_ID,

  smtpHost: parsed.SMTP_HOST || 'smtp.gmail.com',
  smtpPort: parsed.SMTP_PORT || 587,
  smtpUser: parsed.SMTP_USER,
  smtpPass: parsed.SMTP_PASS,
  otpExpiryMinutes: parsed.OTP_EXPIRY_MINUTES || 5,
  otpPepper: parsed.OTP_PEPPER || '',
  cronSecret: parsed.CRON_SECRET || '',

  cloudinaryCloudName: parsed.CLOUDINARY_CLOUD_NAME,
  cloudinaryApiKey: parsed.CLOUDINARY_API_KEY,
  cloudinaryApiSecret: parsed.CLOUDINARY_API_SECRET,

  firebaseServiceAccountPath: parsed.FIREBASE_SERVICE_ACCOUNT_PATH,
  firebaseServiceAccountJson: parsed.FIREBASE_SERVICE_ACCOUNT_JSON || '',

  stripeSecretKey: parsed.STRIPE_SECRET_KEY,
  stripeWebhookSecret: parsed.STRIPE_WEBHOOK_SECRET,

  likeRateLimitWindowMs: parsed.LIKE_RATE_LIMIT_WINDOW_MS,
  likeRateLimitMax: parsed.LIKE_RATE_LIMIT_MAX,

  redisUrl: parsed.REDIS_URL || 'redis://localhost:6379',

  corsOrigins: parsed.CORS_ORIGINS
    ? csvList.parse(parsed.CORS_ORIGINS)
    : ['http://localhost:3000'],

  sentryDsn: parsed.SENTRY_DSN || '',

  maxRequestBodySize: parsed.MAX_REQUEST_BODY_SIZE,
  socketMaxPayloadBytes: parsed.SOCKET_MAX_PAYLOAD_BYTES,
  mongoTransactionsEnabled: parsed.MONGO_TRANSACTIONS_ENABLED,
  reportAutoSuspendThreshold: parsed.REPORT_AUTO_SUSPEND_THRESHOLD,
  maxPhotoSizeBytes: parsed.MAX_PHOTO_SIZE_BYTES,

  appDeepLinkScheme: parsed.APP_DEEP_LINK_SCHEME || 'reversematch',
  appBaseUrl: parsed.APP_BASE_URL || 'http://localhost:5000',
  privacyPolicyUrl: parsed.PRIVACY_POLICY_URL || '',
  termsOfServiceUrl: parsed.TERMS_OF_SERVICE_URL || '',
  supportEmail: parsed.SUPPORT_EMAIL || 'support@reversematch.app',
  minAppVersion: parsed.MIN_APP_VERSION || '1.0.0',

  workerMetricsPort: parsed.WORKER_METRICS_PORT,
  bullmqQueuePrefix: parsed.BULLMQ_QUEUE_PREFIX,

  // Phase 1.4
  idempotencyTtlSeconds: parsed.IDEMPOTENCY_TTL_SECONDS,
  idempotencyInflightTimeoutMs: parsed.IDEMPOTENCY_INFLIGHT_TIMEOUT_MS,

  // Phase 1.2
  mediaReaperIntervalMs: parsed.MEDIA_REAPER_INTERVAL_MS,

  // ML matchmaker
  mlServiceUrl: parsed.ML_SERVICE_URL || '',
  mlServiceApiKey: parsed.ML_SERVICE_API_KEY || '',
  mlServiceTimeoutMs: parsed.ML_SERVICE_TIMEOUT_MS,
};

// Attach the validator + table as non-enumerable helpers, THEN freeze. Doing
// this before the freeze matters: the previous code froze `config` first and
// then assigned `module.exports.validateConfig`, which silently no-ops on a
// frozen object in CommonJS sloppy mode and left `validateConfig` undefined
// (this broke `npm run check:env`). Non-enumerable keeps them off the data
// surface while still exposing them to the check script and unit tests.
Object.defineProperty(config, 'validateConfig', { value: validateConfig, enumerable: false });
Object.defineProperty(config, 'PROD_REQUIRED', { value: PROD_REQUIRED, enumerable: false });

module.exports = Object.freeze(config);
