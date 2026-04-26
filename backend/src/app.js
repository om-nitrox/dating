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
const { initSentry, Sentry } = require('./config/sentry');
const { getRedis } = require('./config/redis');
const logger = require('./utils/logger');

// Initialize Sentry early
initSentry();

const app = express();

// Trust proxy (Nginx)
app.set('trust proxy', 1);

// Stripe webhook needs raw body - mount before json parser
app.post(
  '/api/v1/boost/webhook',
  express.raw({ type: 'application/json' }),
  require('./controllers/boost.controller').handleWebhook
);

// Security middleware
app.use(helmet());

// CORS — locked to specific origins
app.use(
  cors({
    origin: true, // Allow all origins (mobile app + web)
    credentials: true,
    methods: ['GET', 'POST', 'PUT', 'PATCH', 'DELETE', 'OPTIONS'],
    allowedHeaders: ['Content-Type', 'Authorization'],
    maxAge: 86400, // Preflight cache 24h
  })
);

app.use(compression());
app.use(express.json({ limit: config.maxRequestBodySize }));
app.use(express.urlencoded({ extended: true }));

// NoSQL injection sanitization
app.use(sanitize);

// Request logging
if (config.nodeEnv === 'development') {
  app.use(morgan('dev'));
} else {
  // Structured access logging in production
  app.use(
    morgan(':method :url :status :response-time ms', {
      stream: { write: (msg) => logger.info(msg.trim()) },
    })
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

// App config endpoint (privacy policy, terms URLs)
app.get('/api/v1/config', (req, res) => {
  res.json({
    privacyPolicyUrl: config.privacyPolicyUrl,
    termsOfServiceUrl: config.termsOfServiceUrl,
  });
});

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
