// Phase 0.9: observability scaffold.
/**
 * Prometheus metrics registry, shared across the api process and the
 * BullMQ worker.
 *
 * Why one shared registry:
 *   - Both processes export `/metrics` on different ports (api 5000,
 *     worker 9091 via `config.workerMetricsPort`). The Prometheus scrape
 *     config treats them as separate targets but they reuse the SAME
 *     custom metric definitions so dashboards / alerts can be written
 *     once.
 *   - Centralizing creation also avoids the "metric registered twice"
 *     error prom-client throws when the same metric name is created on
 *     two registries — a real risk when both api and worker code paths
 *     pull in the same module.
 *
 * Default Node metrics:
 *   `collectDefaultMetrics({ register })` enables process_*, nodejs_*,
 *   and event-loop lag — all the standard exporter set.
 *
 * Named custom metrics — see ARCHITECTURE_REVIEW Part 2 §5 for the list.
 *
 * Calling `httpMetricsMiddleware()` mounts the Express-side
 * request/duration tracking. The worker calls `markJobStart` /
 * `markJobEnd` from its `completed` / `failed` listeners.
 */

const promClient = require('prom-client');

// Single shared registry across api and worker processes.
const register = new promClient.Registry();

// Default Node + process metrics (event loop lag, GC, heap, etc.).
promClient.collectDefaultMetrics({ register });

// --------------------------------------------------------------------
// HTTP
// --------------------------------------------------------------------
const httpRequestsTotal = new promClient.Counter({
  name: 'http_requests_total',
  help: 'Total HTTP requests processed',
  labelNames: ['method', 'route', 'status'],
  registers: [register],
});

const httpRequestDurationSeconds = new promClient.Histogram({
  name: 'http_request_duration_seconds',
  help: 'HTTP request duration in seconds',
  labelNames: ['method', 'route', 'status'],
  // Buckets tuned for a 1ms..30s API surface. The default prom-client
  // buckets (0.005..10) are too generous for our typical p50 (<50ms).
  buckets: [0.005, 0.01, 0.025, 0.05, 0.1, 0.25, 0.5, 1, 2.5, 5, 10],
  registers: [register],
});

// --------------------------------------------------------------------
// Sockets
// --------------------------------------------------------------------
const socketConnectionsActive = new promClient.Gauge({
  name: 'socket_connections_active',
  help: 'Currently-open Socket.IO connections on this process',
  registers: [register],
});

const socketEventsTotal = new promClient.Counter({
  name: 'socket_events_total',
  help: 'Socket.IO events fanned out or received',
  labelNames: ['event', 'direction'], // direction: inbound | outbound
  registers: [register],
});

// --------------------------------------------------------------------
// Jobs (BullMQ)
// --------------------------------------------------------------------
const jobProcessedTotal = new promClient.Counter({
  name: 'job_processed_total',
  help: 'BullMQ jobs processed by status',
  labelNames: ['queue', 'job', 'status'], // status: completed | failed
  registers: [register],
});

const jobDurationSeconds = new promClient.Histogram({
  name: 'job_duration_seconds',
  help: 'BullMQ job processing duration in seconds',
  labelNames: ['queue', 'job'],
  buckets: [0.05, 0.1, 0.25, 0.5, 1, 2.5, 5, 10, 30, 60, 120, 300],
  registers: [register],
});

// --------------------------------------------------------------------
// Business counters
// --------------------------------------------------------------------
const matchCreatedTotal = new promClient.Counter({
  name: 'match_created_total',
  help: 'Matches created (queue.accept commit)',
  registers: [register],
});

const boostActivatedTotal = new promClient.Counter({
  name: 'boost_activated_total',
  help: 'Boost tiers activated (Stripe webhook OR direct activate)',
  labelNames: ['tier'],
  registers: [register],
});

const otpSentTotal = new promClient.Counter({
  name: 'otp_sent_total',
  help: 'OTP emails dispatched (or attempted)',
  labelNames: ['result'], // sent | throttled | failed
  registers: [register],
});

// --------------------------------------------------------------------
// Express middleware
// --------------------------------------------------------------------

/**
 * Express middleware that records HTTP method, route template (NOT raw
 * URL — that explodes cardinality), status code, and duration for every
 * request. Mounted in app.js once near the top of the chain.
 *
 * `req.route?.path` is the matched route pattern (e.g. `/messages/:matchId`)
 * — populated AFTER the route matcher runs, so we read it in the `res.on('finish')`
 * callback. Falls back to the originalUrl path (stripped of querystring) when
 * no route was matched (e.g. 404s).
 */
const httpMetricsMiddleware = () => (req, res, next) => {
  const start = process.hrtime.bigint();
  res.on('finish', () => {
    try {
      const elapsedNs = Number(process.hrtime.bigint() - start);
      const seconds = elapsedNs / 1e9;
      const route = req.route?.path
        ? `${req.baseUrl || ''}${req.route.path}`
        : (req.originalUrl || req.url || '').split('?')[0];
      const labels = {
        method: req.method,
        route,
        status: String(res.statusCode),
      };
      httpRequestsTotal.labels(labels).inc();
      httpRequestDurationSeconds.labels(labels).observe(seconds);
    } catch (_) { /* never throw from a finish hook */ }
  });
  next();
};

/**
 * Express handler returning `Content-Type: text/plain; version=0.0.4`
 * Prometheus exposition format. Mount as `GET /metrics`.
 */
const metricsEndpoint = async (req, res) => {
  try {
    res.setHeader('Content-Type', register.contentType);
    res.end(await register.metrics());
  } catch (err) {
    res.statusCode = 500;
    res.end(err.message);
  }
};

module.exports = {
  register,
  httpRequestsTotal,
  httpRequestDurationSeconds,
  socketConnectionsActive,
  socketEventsTotal,
  jobProcessedTotal,
  jobDurationSeconds,
  matchCreatedTotal,
  boostActivatedTotal,
  otpSentTotal,
  httpMetricsMiddleware,
  metricsEndpoint,
};
