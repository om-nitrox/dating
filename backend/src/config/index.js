const dotenv = require('dotenv');
const path = require('path');

dotenv.config({ path: path.join(__dirname, '../../.env') });

const requiredVars = [
  'MONGO_URI',
  'JWT_ACCESS_SECRET',
  'JWT_REFRESH_SECRET',
];

for (const varName of requiredVars) {
  if (!process.env[varName]) {
    throw new Error(`Missing required environment variable: ${varName}`);
  }
}

const config = Object.freeze({
  port: parseInt(process.env.PORT, 10) || 5000,
  nodeEnv: process.env.NODE_ENV || 'development',
  mongoUri: process.env.MONGO_URI,

  jwtAccessSecret: process.env.JWT_ACCESS_SECRET,
  jwtRefreshSecret: process.env.JWT_REFRESH_SECRET,
  jwtAccessExpiry: process.env.JWT_ACCESS_EXPIRY || '15m',
  jwtRefreshExpiry: process.env.JWT_REFRESH_EXPIRY || '7d',
  // Pre-parsed seconds for access TTL — used for Redis blacklist/ban TTLs.
  jwtAccessExpirySeconds: (() => {
    const raw = process.env.JWT_ACCESS_EXPIRY || '15m';
    const m = String(raw).match(/^(\d+)([smhd])?$/i);
    if (!m) return 900;
    const n = parseInt(m[1], 10);
    const unit = (m[2] || 's').toLowerCase();
    const factor = {
      s: 1, m: 60, h: 3600, d: 86400,
    }[unit] || 1;
    return n * factor;
  })(),

  googleClientId: process.env.GOOGLE_CLIENT_ID,

  smtpHost: process.env.SMTP_HOST || 'smtp.gmail.com',
  smtpPort: parseInt(process.env.SMTP_PORT, 10) || 587,
  smtpUser: process.env.SMTP_USER,
  smtpPass: process.env.SMTP_PASS,
  otpExpiryMinutes: parseInt(process.env.OTP_EXPIRY_MINUTES, 10) || 5,
  // Optional dedicated pepper for OTP HMAC; falls back to JWT_ACCESS_SECRET.
  otpPepper: process.env.OTP_PEPPER || '',

  cloudinaryCloudName: process.env.CLOUDINARY_CLOUD_NAME,
  cloudinaryApiKey: process.env.CLOUDINARY_API_KEY,
  cloudinaryApiSecret: process.env.CLOUDINARY_API_SECRET,

  firebaseServiceAccountPath: process.env.FIREBASE_SERVICE_ACCOUNT_PATH,

  stripeSecretKey: process.env.STRIPE_SECRET_KEY,
  stripeWebhookSecret: process.env.STRIPE_WEBHOOK_SECRET,

  likeRateLimitWindowMs: parseInt(process.env.LIKE_RATE_LIMIT_WINDOW_MS, 10) || 3600000,
  likeRateLimitMax: parseInt(process.env.LIKE_RATE_LIMIT_MAX, 10) || 100,

  // Redis
  redisUrl: process.env.REDIS_URL || 'redis://localhost:6379',

  // CORS
  corsOrigins: process.env.CORS_ORIGINS
    ? process.env.CORS_ORIGINS.split(',').map((s) => s.trim())
    : ['http://localhost:3000'],

  // Sentry
  sentryDsn: process.env.SENTRY_DSN || '',

  // Request limits
  maxRequestBodySize: process.env.MAX_REQUEST_BODY_SIZE || '10mb',
  socketMaxPayloadBytes: parseInt(process.env.SOCKET_MAX_PAYLOAD_BYTES, 10) || 65536, // 64KB

  // Multi-doc transactions require a replica set / Atlas. When false (or when
  // running against standalone Mongo) we fall back to sequential writes with a
  // warning log so local dev continues to work.
  mongoTransactionsEnabled:
    (process.env.MONGO_TRANSACTIONS_ENABLED || 'true').toLowerCase() !== 'false',

  // Moderation
  reportAutoSuspendThreshold: parseInt(process.env.REPORT_AUTO_SUSPEND_THRESHOLD, 10) || 5,

  // Photo upload byte cap (per file). Lowered from 10MB to 5MB.
  maxPhotoSizeBytes: parseInt(process.env.MAX_PHOTO_SIZE_BYTES, 10) || 5 * 1024 * 1024,

  // App deep link scheme for payment returns
  appDeepLinkScheme: process.env.APP_DEEP_LINK_SCHEME || 'reversematch',
  appBaseUrl: process.env.APP_BASE_URL || 'http://localhost:5000',

  // Privacy/Terms URLs
  privacyPolicyUrl: process.env.PRIVACY_POLICY_URL || '',
  termsOfServiceUrl: process.env.TERMS_OF_SERVICE_URL || '',

  // Public app metadata returned by GET /config (spec §10)
  supportEmail: process.env.SUPPORT_EMAIL || 'support@reversematch.app',
  minAppVersion: process.env.MIN_APP_VERSION || '1.0.0',
});

module.exports = config;
