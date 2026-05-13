// Phase 0.9: observability registry unit tests.
//
// Asserts the shared prom-client registry exposes every named metric the
// dashboards and alerts depend on, plus the default Node metrics, plus the
// /metrics endpoint serves Prometheus exposition format with the right
// content type.

// Required env so `src/config/index.js` doesn't throw.
process.env.MONGO_URI = 'mongodb://localhost:27017/test_placeholder';
process.env.JWT_ACCESS_SECRET = 'test-access-secret-32-chars-long!!';
process.env.JWT_REFRESH_SECRET = 'test-refresh-secret-32-chars-long!';
process.env.NODE_ENV = 'test';

const {
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
  metricsEndpoint,
  httpMetricsMiddleware,
} = require('../../../src/observability/metrics');

describe('observability/metrics', () => {
  it('shared registry exposes every named custom metric', async () => {
    const names = (await register.getMetricsAsArray()).map((m) => m.name);
    expect(names).toEqual(expect.arrayContaining([
      'http_requests_total',
      'http_request_duration_seconds',
      'socket_connections_active',
      'socket_events_total',
      'job_processed_total',
      'job_duration_seconds',
      'match_created_total',
      'boost_activated_total',
      'otp_sent_total',
    ]));
  });

  it('shared registry exposes the default Node metrics (collectDefaultMetrics)', async () => {
    const names = (await register.getMetricsAsArray()).map((m) => m.name);
    // At least one signature from the default set.
    expect(names).toEqual(expect.arrayContaining([
      'process_cpu_seconds_total',
    ]));
  });

  it('exposes each metric on its public export so call sites can `.inc()` / `.observe()`', () => {
    expect(typeof httpRequestsTotal.inc).toBe('function');
    expect(typeof httpRequestDurationSeconds.observe).toBe('function');
    expect(typeof socketConnectionsActive.inc).toBe('function');
    expect(typeof socketConnectionsActive.dec).toBe('function');
    expect(typeof socketEventsTotal.inc).toBe('function');
    expect(typeof jobProcessedTotal.inc).toBe('function');
    expect(typeof jobDurationSeconds.observe).toBe('function');
    expect(typeof matchCreatedTotal.inc).toBe('function');
    expect(typeof boostActivatedTotal.inc).toBe('function');
    expect(typeof otpSentTotal.inc).toBe('function');
  });

  it('bumping a counter is reflected in the exposition payload', async () => {
    matchCreatedTotal.inc();
    const text = await register.metrics();
    expect(text).toMatch(/^match_created_total\s/m);
  });

  it('metricsEndpoint serves Prometheus exposition format', async () => {
    const headers = {};
    const res = {
      setHeader: (k, v) => { headers[k] = v; },
      end: (body) => { res.body = body; },
      statusCode: 200,
    };
    await metricsEndpoint({}, res);
    expect(headers['Content-Type']).toMatch(/text\/plain/);
    expect(res.body).toMatch(/^# HELP /m);
  });

  it('httpMetricsMiddleware records the request after res.finish', async () => {
    const middleware = httpMetricsMiddleware();
    const listeners = {};
    // Use a unique route path so the assertion is robust to other tests
    // having bumped the same series.
    const route = `/test-${Date.now()}`;
    const req = { method: 'GET', route: { path: route }, baseUrl: '' };
    const res = {
      on(event, fn) { listeners[event] = fn; },
      statusCode: 200,
    };
    const next = jest.fn();
    middleware(req, res, next);
    expect(next).toHaveBeenCalled();
    // Trigger the finish callback — counts get bumped.
    listeners.finish();
    const text = await register.metrics();
    expect(text).toContain(`route="${route}"`);
  });
});
