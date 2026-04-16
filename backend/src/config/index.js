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

  googleClientId: process.env.GOOGLE_CLIENT_ID,

  smtpHost: process.env.SMTP_HOST || 'smtp.gmail.com',
  smtpPort: parseInt(process.env.SMTP_PORT, 10) || 587,
  smtpUser: process.env.SMTP_USER,
  smtpPass: process.env.SMTP_PASS,
  otpExpiryMinutes: parseInt(process.env.OTP_EXPIRY_MINUTES, 10) || 5,

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

  // App deep link scheme for payment returns
  appDeepLinkScheme: process.env.APP_DEEP_LINK_SCHEME || 'reversematch',
  appBaseUrl: process.env.APP_BASE_URL || 'http://localhost:5000',

  // Privacy/Terms URLs
  privacyPolicyUrl: process.env.PRIVACY_POLICY_URL || '',
  termsOfServiceUrl: process.env.TERMS_OF_SERVICE_URL || '',
});

module.exports = config;
