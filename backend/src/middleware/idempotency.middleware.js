// Phase 1.4: idempotency middleware for mutating endpoints.
/**
 * Redis-backed idempotency replay cache.
 *
 * Why:
 *   POSTs are not idempotent by default. A flaky mobile network can produce
 *   "client thinks it failed but server actually succeeded" duplicates —
 *   double-likes, double-messages, double-reports. The Stripe pattern is a
 *   client-supplied `Idempotency-Key` header that the server uses to dedup.
 *
 * Behaviour:
 *   1. Read `Idempotency-Key` from the request headers. If absent, the
 *      middleware is a no-op (caller opted out).
 *   2. Validate the header is a UUID (any version). Invalid -> 400.
 *   3. Cache key:
 *        idempotency:<userId>:<routeBase>:<idempotencyKey>
 *      The userId is required — anonymous endpoints don't use this
 *      middleware, so `req.user.id` is guaranteed by the upstream auth.
 *   4. SETNX a "in-flight" marker. On first request:
 *        - Forward to the route handler.
 *        - Capture `{ status, body, headers }` on `res.end()` and persist
 *          to Redis with the configured TTL (default 24h).
 *      On retry with same key:
 *        - If the cached entry is the in-flight marker, poll briefly (up to
 *          `idempotencyInflightTimeoutMs`) waiting for the original request
 *          to finish, then replay its response.
 *        - If the cached entry is a completed response, replay it
 *          immediately.
 *        - If we time out waiting on the in-flight marker, return 409
 *          Conflict (the request is already being processed; retry later).
 *
 * Atomicity notes:
 *   We don't try to use Lua / WATCH — a single SETNX with EX is enough for
 *   the "first writer wins" gate. The "polling on in-flight" loop is the
 *   weakest part: two retries that miss the SETNX race may both end up
 *   replaying, but the underlying side-effect happens exactly once because
 *   only the SETNX winner reaches the route handler.
 *
 * Trade-offs vs Stripe:
 *   - Stripe stores the request body hash to detect "same key, different
 *     body". We skip this for v1 — the cache is keyed off userId already,
 *     so a key collision across users is impossible, and a same-user/same-
 *     key/different-body is a client bug we don't need to disambiguate.
 *
 * Apply to:
 *   POST /messages, POST /swipe/like, POST /queue/accept/:likeId,
 *   POST /report, POST /block, DELETE /matches/:matchId,
 *   DELETE /profile/photos/:publicId.
 */

const config = require('../config');
const { getRedis } = require('../config/redis');
const AppError = require('../utils/AppError');
const logger = require('../utils/logger');

const UUID_RE = /^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$/;

// Sentinel stored under the idempotency key while the original request is
// still running. Distinguishable from a real cached response by the absence
// of a `status` field.
const INFLIGHT_MARKER = '__inflight__';

// Header allow-list to replay. We deliberately do NOT replay everything —
// some headers (Date, Connection, etc.) should be re-generated. We keep the
// content-type, cache-control, and the request id from the ORIGINAL request
// so log correlation still works.
const REPLAYABLE_HEADERS = new Set([
  'content-type',
  'cache-control',
  'location',
  'x-request-id',
]);

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

/**
 * Stringify a JS value for Redis. Objects -> JSON; everything else -> String.
 */
const serialize = (obj) => JSON.stringify(obj);

const deserialize = (raw) => {
  if (raw === null || raw === undefined) return null;
  if (raw === INFLIGHT_MARKER) return { inflight: true };
  try {
    return JSON.parse(raw);
  } catch (_) {
    return null;
  }
};

/**
 * Build a cache key. routeBase is the route template (e.g.
 * `/messages` or `/queue/accept/:likeId`) — using the template instead of
 * the raw URL keeps the keyspace bounded.
 */
const buildKey = (userId, routeBase, idempotencyKey) => (
  `idempotency:${userId}:${routeBase}:${idempotencyKey}`
);

/**
 * Replay a cached response onto an Express `res`. Returns true on success.
 */
const replayCached = (res, cached) => {
  if (!cached || typeof cached.status !== 'number') return false;
  if (cached.headers) {
    for (const [k, v] of Object.entries(cached.headers)) {
      if (REPLAYABLE_HEADERS.has(k.toLowerCase())) {
        res.setHeader(k, v);
      }
    }
  }
  // Add a marker header so clients can observe that this was a replay.
  res.setHeader('Idempotent-Replay', 'true');
  res.status(cached.status);
  if (cached.body !== undefined && cached.body !== null) {
    // body was stored as the JSON-stringified payload; deserialize before
    // re-sending so Express doesn't double-encode.
    res.json(cached.body);
  } else {
    res.end();
  }
  return true;
};

/**
 * Build the middleware. `routeBase` lets the caller pass the route template
 * explicitly (otherwise we derive it from `req.baseUrl + req.route?.path`).
 */
const idempotency = (opts = {}) => async (req, res, next) => {
  const headerKey = req.headers['idempotency-key'];
  if (!headerKey) {
    // No header => no idempotency. This is the documented opt-out path.
    return next();
  }

  if (typeof headerKey !== 'string' || !UUID_RE.test(headerKey)) {
    return next(new AppError('Idempotency-Key must be a UUID', 400, 'INVALID_IDEMPOTENCY_KEY'));
  }

  // We require an authenticated user — the cache key is namespaced by user
  // to prevent cross-tenant key collisions.
  const userId = req.user && req.user.id;
  if (!userId) {
    return next(new AppError('Idempotency requires authentication', 401));
  }

  // Compute the cache key. Use the route template (req.route?.path) over
  // the raw URL so dynamic segments like /matches/:matchId don't blow up
  // the keyspace.
  const routeBase = opts.routeBase
    || `${req.baseUrl || ''}${req.route && req.route.path ? req.route.path : (req.path || req.url)}`;
  const cacheKey = buildKey(userId, routeBase, headerKey);

  let redis;
  try {
    redis = getRedis();
  } catch (err) {
    // If Redis isn't available we can't do idempotency. Fail open — the
    // request still runs, just without dedup. Production should always have
    // Redis (Phase 1.6 enforces this); this branch is a dev-safety net.
    logger.warn({ err: err.message, cacheKey }, 'Idempotency Redis unavailable; falling through');
    return next();
  }

  // Some test setups use an ioredis mock whose `status` stays at 'connecting'
  // forever. Treat that as Redis-not-ready and fall through silently.
  if (redis && redis.status && redis.status !== 'ready' && redis.status !== 'connect' && redis.status !== 'connecting') {
    return next();
  }

  // ---- Phase 1: SETNX in-flight marker ----
  let acquired;
  try {
    const setRes = await redis.set(
      cacheKey,
      INFLIGHT_MARKER,
      'EX',
      config.idempotencyTtlSeconds,
      'NX',
    );
    acquired = setRes === 'OK';
  } catch (err) {
    logger.warn({ err: err.message, cacheKey }, 'Idempotency SETNX failed; falling through');
    return next();
  }

  if (acquired) {
    // First time: hook res to capture the response body, then continue.
    const chunks = [];
    let captured = false;

    const originalJson = res.json.bind(res);
    res.json = (body) => {
      // Capture the body BEFORE writing so we can re-serialize on replay.
      if (!captured) {
        captured = true;
        const entry = {
          status: res.statusCode,
          body,
          headers: {
            'content-type': 'application/json; charset=utf-8',
            'x-request-id': req.id,
          },
          createdAt: Date.now(),
        };
        // Fire-and-forget persist. If Redis is down we just lose the cache
        // entry — the in-flight marker will TTL out and the next retry
        // will re-execute, which is the safer side of "fail open".
        redis
          .set(cacheKey, serialize(entry), 'EX', config.idempotencyTtlSeconds)
          .catch((err) => logger.warn(
            { err: err.message, cacheKey },
            'Idempotency cache write failed',
          ));
      }
      return originalJson(body);
    };

    // If the handler ends WITHOUT calling res.json (e.g. res.sendStatus,
    // res.end, an error), clean up the in-flight marker so retries can
    // proceed without hitting the 409 fallback for the full TTL.
    res.on('finish', () => {
      if (!captured) {
        // Persist the status-only response so retries see SOMETHING and
        // don't hang on the in-flight poll. We don't store an arbitrary
        // body — only the status and the x-request-id.
        const entry = {
          status: res.statusCode,
          body: null,
          headers: { 'x-request-id': req.id },
          createdAt: Date.now(),
        };
        redis
          .set(cacheKey, serialize(entry), 'EX', config.idempotencyTtlSeconds)
          .catch(() => {});
      }
    });

    // Ignore unused chunks; included only so future readers see the buffer
    // is intentionally not used.
    if (chunks.length > 0) chunks.length = 0;

    return next();
  }

  // ---- Phase 2: retry path — wait briefly or replay ----
  const deadline = Date.now() + config.idempotencyInflightTimeoutMs;
  const pollIntervalMs = 100;

  // eslint-disable-next-line no-constant-condition
  while (true) {
    let raw;
    try {
      // eslint-disable-next-line no-await-in-loop
      raw = await redis.get(cacheKey);
    } catch (err) {
      logger.warn({ err: err.message, cacheKey }, 'Idempotency GET failed during retry');
      return next();
    }

    const cached = deserialize(raw);

    if (cached && cached.inflight) {
      if (Date.now() >= deadline) {
        // Couldn't wait any longer. Return 409 so the client can retry.
        return next(new AppError(
          'Original request still in flight; retry shortly',
          409,
          'IDEMPOTENT_INFLIGHT',
        ));
      }
      // eslint-disable-next-line no-await-in-loop
      await sleep(pollIntervalMs);
      // eslint-disable-next-line no-continue
      continue;
    }

    if (cached && typeof cached.status === 'number') {
      // Replay the captured response.
      const replayed = replayCached(res, cached);
      if (!replayed) {
        // Defensive fallback — corrupted cache entry. Fall through to
        // re-execute rather than 500.
        return next();
      }
      return undefined; // response already written
    }

    // No cache and no in-flight marker (TTL elapsed mid-retry). Re-execute.
    return next();
  }
};

module.exports = { idempotency, buildKey, INFLIGHT_MARKER };
