/**
 * Thin HTTP client for the ml-service Python microservice.
 *
 * Design notes:
 *   - All calls are bounded by ML_SERVICE_TIMEOUT_MS so a slow ML host can't
 *     stall the API. Default 2.5s, well below typical request budgets.
 *   - `isEnabled()` is the single switch the rest of the backend uses. When
 *     ML_SERVICE_URL is empty (e.g. local dev without compose), every helper
 *     short-circuits and the legacy Node cosine path takes over.
 *   - `recordEvent` is fire-and-forget for the hot swipe path. Errors are
 *     swallowed with a debug log — a missing ML hit must NEVER fail a user
 *     swipe.
 */
const logger = require('../utils/logger');

const ML_SERVICE_URL = (process.env.ML_SERVICE_URL || '').trim();
const ML_SERVICE_API_KEY = process.env.ML_SERVICE_API_KEY || '';
const ML_SERVICE_TIMEOUT_MS = parseInt(process.env.ML_SERVICE_TIMEOUT_MS, 10) || 2500;

const isEnabled = () => Boolean(ML_SERVICE_URL);

const baseUrl = () => ML_SERVICE_URL.replace(/\/+$/, '');

const buildHeaders = () => {
  const h = { 'Content-Type': 'application/json', Accept: 'application/json' };
  if (ML_SERVICE_API_KEY) h['x-api-key'] = ML_SERVICE_API_KEY;
  return h;
};

const callJson = async (method, path, body, timeoutMs = ML_SERVICE_TIMEOUT_MS) => {
  if (!isEnabled()) return null;

  const ctrl = new AbortController();
  const timer = setTimeout(() => ctrl.abort(), timeoutMs);
  try {
    const res = await fetch(`${baseUrl()}${path}`, {
      method,
      headers: buildHeaders(),
      body: body === undefined ? undefined : JSON.stringify(body),
      signal: ctrl.signal,
    });
    if (!res.ok) {
      const text = await res.text().catch(() => '');
      logger.warn(
        {
          event: 'ml.http_error', status: res.status, path, body: text.slice(0, 200),
        },
        'ml-service returned non-2xx',
      );
      return null;
    }
    return await res.json();
  } catch (err) {
    // AbortError, network error, JSON parse error — all degrade gracefully.
    logger.warn(
      { event: 'ml.request_failed', err: err.message, path },
      'ml-service request failed',
    );
    return null;
  } finally {
    clearTimeout(timer);
  }
};

/**
 * Ask the ML service to rank candidates for `userId`.
 *
 * When `allowedCandidateIds` is provided, the ML service ranks ONLY within
 * that set (a hard pre-filtered pool — e.g. the girl's age/height/intent
 * filters already applied in Mongo). This is how discovery filters constrain
 * the Ideal Match result while the embedding model still does the ranking.
 */
const recommend = (userId, k = 20, allowedCandidateIds = null) => {
  const body = { user_id: String(userId), k };
  if (Array.isArray(allowedCandidateIds)) {
    body.allowed_candidate_ids = allowedCandidateIds.map(String);
  }
  return callJson('POST', '/v1/recommend', body);
};

const dailyMatch = (userId) => callJson('GET', `/v1/daily-match/${encodeURIComponent(String(userId))}`);

const weeklyMatches = (userId) => callJson('GET', `/v1/weekly-matches/${encodeURIComponent(String(userId))}`);

/**
 * Fire-and-forget. Used from swipe.service so the hot path doesn't block.
 * The caller MUST NOT await this if they care about latency.
 */
const recordEvent = (userId, targetId, eventType) => {
  if (!isEnabled()) return;
  // Decouple from the request lifecycle entirely.
  setImmediate(() => {
    callJson(
      'POST',
      '/v1/event',
      {
        user_id: String(userId),
        target_id: String(targetId),
        event_type: eventType,
        timestamp: Date.now() / 1000,
      },
      // Slightly looser timeout — these are background updates.
      Math.max(ML_SERVICE_TIMEOUT_MS, 5000),
    ).catch(() => {});
  });
};

const rebuildIndex = () => callJson('POST', '/v1/admin/rebuild', {}, 60_000);

module.exports = {
  isEnabled,
  recommend,
  dailyMatch,
  weeklyMatches,
  recordEvent,
  rebuildIndex,
};
