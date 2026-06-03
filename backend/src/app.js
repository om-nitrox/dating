const express = require('express');
const cors = require('cors');
const helmet = require('helmet');
const morgan = require('morgan');
const compression = require('compression');
const mongoose = require('mongoose');
const config = require('./config');
const routes = require('./routes');
const errorMiddleware = require('./middleware/error.middleware');
const sanitize = require('./middleware/sanitize.middleware');
const requestId = require('./middleware/requestId.middleware');
const { initSentry, Sentry } = require('./config/sentry');
const { getRedis } = require('./config/redis');
const logger = require('./utils/logger');
const {
  httpMetricsMiddleware, metricsEndpoint,
} = require('./observability/metrics');

// Initialize Sentry early
initSentry();

const app = express();

// Trust proxy (Nginx)
app.set('trust proxy', 1);

// Request-ID middleware — Phase 0.5.
// MUST be mounted before everything else so `req.id` is available to all
// downstream middleware, route handlers, and the error middleware. Tags the
// response with `X-Request-Id` and attaches a child pino logger as `req.log`.
app.use(requestId);

// HTTP metrics — Phase 0.9. Mounted right after request-id so every
// timed request also carries a correlation id in its log lines.
app.use(httpMetricsMiddleware());

// Sentry: tag every event with the current request id. We set the scope tag
// at the start of each request — Sentry.setupExpressErrorHandler() (mounted
// below) will read this scope when reporting.
if (config.sentryDsn) {
  app.use((req, res, next) => {
    try {
      Sentry.getCurrentScope().setTag('request_id', req.id);
    } catch (_) {
      // Sentry may not be fully initialized in tests; silently skip.
    }
    next();
  });
}

// Stripe webhook needs raw body - mount before json parser
app.post(
  '/api/v1/boost/webhook',
  express.raw({ type: 'application/json' }),
  require('./controllers/boost.controller').handleWebhook,
);

// Security middleware
app.use(helmet());

// CORS — locked to specific origins
// In production, only origins on the allow-list may use credentials.
// In dev, allow any origin so Flutter (simulator/emulator/web) can connect.
const corsOptions = config.nodeEnv === 'production'
  ? {
    origin: (origin, cb) => {
      // Same-origin / non-browser requests (no Origin header) always pass.
      // Browser requests must match the configured CORS_ORIGINS list.
      if (!origin) return cb(null, true);
      if (config.corsOrigins.includes(origin)) return cb(null, true);
      return cb(new Error('CORS: origin not allowed'));
    },
    credentials: true,
    methods: ['GET', 'POST', 'PUT', 'PATCH', 'DELETE', 'OPTIONS'],
    allowedHeaders: ['Content-Type', 'Authorization'],
    maxAge: 86400,
  }
  : {
    origin: true,
    credentials: true,
    methods: ['GET', 'POST', 'PUT', 'PATCH', 'DELETE', 'OPTIONS'],
    allowedHeaders: ['Content-Type', 'Authorization'],
    maxAge: 86400,
  };
app.use(cors(corsOptions));

app.use(compression());
app.use(express.json({ limit: config.maxRequestBodySize }));
app.use(express.urlencoded({ extended: true }));

// NoSQL injection sanitization
app.use(sanitize);

// Request logging
// Custom token so production access-log lines carry the request id (Phase 0.5).
morgan.token('req_id', (req) => req.id || '-');
if (config.nodeEnv === 'development') {
  app.use(morgan('dev'));
} else {
  // Structured access logging in production
  app.use(
    morgan(':method :url :status :response-time ms req_id=:req_id', {
      stream: { write: (msg) => logger.info(msg.trim()) },
    }),
  );
}

// Request timeout (30 seconds)
app.use((req, res, next) => {
  req.setTimeout(30000, () => {
    res.status(408).json({
      error: { code: 'REQUEST_TIMEOUT', message: 'Request timed out' },
    });
  });
  next();
});

// Prometheus metrics — Phase 0.9.
// Unauthenticated; relies on network ACLs to keep external scrapers out.
// ECS scrapers run inside the VPC.
app.get('/metrics', metricsEndpoint);

// Deep health check
app.get('/health', async (req, res) => {
  const checks = {
    status: 'ok',
    timestamp: new Date().toISOString(),
    uptime: process.uptime(),
    services: {},
  };

  // MongoDB check
  try {
    const mongoState = mongoose.connection.readyState;
    checks.services.mongodb = mongoState === 1 ? 'connected' : 'disconnected';
    if (mongoState !== 1) checks.status = 'degraded';
  } catch {
    checks.services.mongodb = 'error';
    checks.status = 'degraded';
  }

  // Redis check
  try {
    const redis = getRedis();
    if (redis.status === 'ready') {
      await redis.ping();
      checks.services.redis = 'connected';
    } else {
      checks.services.redis = 'disconnected';
      checks.status = 'degraded';
    }
  } catch {
    checks.services.redis = 'unavailable';
    // Redis is optional, don't degrade status
  }

  const statusCode = checks.status === 'ok' ? 200 : 503;
  res.status(statusCode).json(checks);
});

// Readiness probe (for k8s)
app.get('/ready', (req, res) => {
  const mongoReady = mongoose.connection.readyState === 1;
  if (mongoReady) {
    res.status(200).json({ ready: true });
  } else {
    res.status(503).json({ ready: false });
  }
});

// Boost payment redirect pages — redirect to app deep link after Stripe checkout
app.get('/api/v1/boost/success', (req, res) => {
  const deepLink = `${config.appDeepLinkScheme}://boost/success`;
  res.send(`
    <html>
      <head><title>Payment Successful</title></head>
      <body style="display:flex;justify-content:center;align-items:center;height:100vh;font-family:sans-serif;flex-direction:column;">
        <h1>Payment Successful!</h1>
        <p>Your boost has been activated.</p>
        <p><a href="${deepLink}">Return to app</a></p>
        <script>window.location.href="${deepLink}";</script>
      </body>
    </html>
  `);
});

app.get('/api/v1/boost/cancel', (req, res) => {
  const deepLink = `${config.appDeepLinkScheme}://boost/cancel`;
  res.send(`
    <html>
      <head><title>Payment Cancelled</title></head>
      <body style="display:flex;justify-content:center;align-items:center;height:100vh;font-family:sans-serif;flex-direction:column;">
        <h1>Payment Cancelled</h1>
        <p>You were not charged.</p>
        <p><a href="${deepLink}">Return to app</a></p>
        <script>window.location.href="${deepLink}";</script>
      </body>
    </html>
  `);
});

// App config endpoint (legal URLs, support email, min app version).
// Spec §10: no auth required. Mounted here (above /api/v1) so the routes
// index doesn't accidentally guard it with the global auth middleware.
app.get('/api/v1/config', (req, res) => {
  res.json({
    termsOfServiceUrl: config.termsOfServiceUrl,
    privacyPolicyUrl: config.privacyPolicyUrl,
    supportEmail: config.supportEmail,
    minAppVersion: config.minAppVersion,
  });
});

// Internal cron endpoints (Catalyst Cron → authenticated via X-Cron-Secret).
// Mounted above /api/v1 so it isn't guarded by the API's auth middleware.
app.use('/internal/cron', require('./routes/internal.routes'));

// API routes
app.use('/api/v1', routes);

// 404 handler
app.use((req, res) => {
  res.status(404).json({
    error: { code: 'NOT_FOUND', message: `Route ${req.originalUrl} not found` },
  });
});

// Sentry error handler (must be before custom error middleware)
if (config.sentryDsn) {
  Sentry.setupExpressErrorHandler(app);
}

// Global error handler
app.use(errorMiddleware);

module.exports = app;
