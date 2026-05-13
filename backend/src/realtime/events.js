// Phase 0.6: realtime event-bus.
/**
 * Centralized Socket.IO emitter module.
 *
 * Why this exists:
 *   Before Phase 0.6, every controller and the chat handler scattered
 *   `io.to(room).emit('event', payload)` calls inline. Three failure modes
 *   were hard to prevent:
 *     1. Event-name typos that the type system can't catch (kebab-case
 *        strings).
 *     2. Payload shape drift between the AsyncAPI spec and what the
 *        backend actually emits.
 *     3. Room-targeting bugs (forgetting one participant's personal room).
 *   By funneling every outbound emit through this module:
 *     - The event-name strings live in exactly one place (the `EVENTS`
 *       object below).
 *     - Each function validates its payload at runtime against the zod
 *       schema generated from `docs/api/openapi.yaml` (Phase 0.3). In
 *       tests this would surface a contract bug; in production we LOG
 *       the mismatch and still emit so a broken validator can't silently
 *       drop messages.
 *     - Room computation (e.g. "fan out to both participants' personal
 *       rooms") is handled internally so callers can't forget a side.
 *     - Phase 0.9 hooks the prom-client `socket_events_total` counter
 *       here for free.
 *
 * AsyncAPI source of truth:
 *   docs/api/asyncapi.yaml — every function below maps 1:1 to a
 *   `subscribe` operation in that doc.
 */

const logger = require('../utils/logger');
const { schemas } = require('../validators/generated');

// -------- Event-name constants (single source of truth) --------
// Mirrors the channel keys in docs/api/asyncapi.yaml.
const EVENTS = Object.freeze({
  NEW_MESSAGE: 'new-message',
  USER_TYPING: 'user-typing',
  MESSAGES_SEEN: 'messages-seen',
  NEW_MATCH: 'new-match',
  NEW_LIKE: 'new-like',
  // `match-deleted` is not in the AsyncAPI spec but is emitted by the
  // backend on unmatch (see openapi.yaml /matches/{matchId} DELETE
  // description: "Optionally emits a `match-deleted` socket event").
  MATCH_DELETED: 'match-deleted',
});

// -------- prom-client counter wiring (Phase 0.9 cross-cut) --------
// Loaded lazily so the realtime module can be required from tests that
// don't initialize the metrics registry.
let metrics;
const getMetrics = () => {
  if (metrics === undefined) {
    try {
      // eslint-disable-next-line global-require
      metrics = require('../observability/metrics');
    } catch (_) {
      metrics = null;
    }
  }
  return metrics;
};

const bumpOutbound = (event) => {
  const m = getMetrics();
  if (m && m.socketEventsTotal) {
    try {
      m.socketEventsTotal.labels({ event, direction: 'outbound' }).inc();
    } catch (_) { /* never fail an emit because of metrics */ }
  }
};

// Public hook used by the inbound socket handler.
const recordInboundEvent = (event) => {
  const m = getMetrics();
  if (m && m.socketEventsTotal) {
    try {
      m.socketEventsTotal.labels({ event, direction: 'inbound' }).inc();
    } catch (_) { /* swallow */ }
  }
};

// -------- Payload validation helpers --------

/**
 * Best-effort runtime validation. On mismatch we LOG (with the request-id
 * child logger when the caller passes one in `opts.log`) and emit anyway —
 * dropping a real-time message because of a schema check is worse than
 * a noisy log line.
 */
const validatePayload = (event, schema, payload, opts = {}) => {
  if (!schema || typeof schema.safeParse !== 'function') return;
  const result = schema.safeParse(payload);
  if (!result.success) {
    const log = opts.log || logger;
    log.warn(
      {
        event,
        issues: result.error.issues.map((i) => `${i.path.join('.')}: ${i.message}`),
      },
      'realtime: outbound payload failed AsyncAPI shape check',
    );
  }
};

const emitToRooms = (io, event, rooms, payload) => {
  // De-duplicate rooms before broadcasting so a single payload doesn't get
  // delivered twice when match.users contains the same id twice (defensive)
  // or when the chat-room name happens to equal a user's personal room.
  const seen = new Set();
  for (const room of rooms) {
    if (!room) continue;
    const key = String(room);
    if (seen.has(key)) continue;
    seen.add(key);
    io.to(key).emit(event, payload);
  }
  bumpOutbound(event);
};

// =====================================================================
// Public emit API — one function per AsyncAPI subscribe operation
// =====================================================================

/**
 * `new-message` — fanned out to:
 *   - the chat-scoped match room (everyone with the chat screen open)
 *   - each participant's personal room (so list badges refresh when the
 *     chat screen is closed)
 *
 * Caller MUST supply both `matchId` and `message` (full MessageModel)
 * AND the array of `participantIds` so we can compute the personal rooms
 * without re-querying the DB.
 */
const emitNewMessage = (io, {
  matchId, message, participantIds, log,
}) => {
  if (!io) return;
  const payload = { matchId, message };
  validatePayload(EVENTS.NEW_MESSAGE, schemas.MessageModel, message, { log });
  const rooms = [matchId, ...(participantIds || []).map((u) => u.toString())];
  emitToRooms(io, EVENTS.NEW_MESSAGE, rooms, payload);
};

/**
 * `user-typing` — emitted INTO the match room (everyone with the chat
 * open). The frontend filters out its own user-id so the typer doesn't
 * see their own indicator.
 *
 * `excludeSocket` is the Socket.IO socket instance for the typer; when
 * present we use `socket.to(room)` so the typer's own client doesn't get
 * the echo. Otherwise we broadcast via `io.to(room)`.
 */
const emitUserTyping = (io, {
  matchId, userId, isTyping, excludeSocket, log,
}) => {
  if (!io) return;
  const payload = { matchId, userId, isTyping };
  // Lightweight inline check — AsyncAPI shape is not in the OpenAPI
  // generated schemas, so we don't have a zod for it. We still log on
  // missing keys to flag a programming error.
  if (!matchId || !userId || typeof isTyping !== 'boolean') {
    (log || logger).warn({ payload }, 'realtime: user-typing payload missing fields');
  }
  if (excludeSocket) {
    excludeSocket.to(matchId).emit(EVENTS.USER_TYPING, payload);
    bumpOutbound(EVENTS.USER_TYPING);
    return;
  }
  io.to(matchId).emit(EVENTS.USER_TYPING, payload);
  bumpOutbound(EVENTS.USER_TYPING);
};

/**
 * `messages-seen` — fan out to the OTHER user's personal room (and into
 * the match room when the caller is currently inside it, via
 * `excludeSocket`).
 *
 * Caller passes:
 *   - `matchId`: the match
 *   - `otherUserId`: the participant who should be told their messages
 *     were seen (i.e. NOT the actor)
 *   - `seenAt`: ISO date
 *   - `excludeSocket` (optional): when emitting from a socket handler,
 *     bounces the event back into the match room without echoing to the
 *     calling socket
 */
const emitMessagesSeen = (io, {
  matchId, otherUserId, seenAt, excludeSocket, log,
}) => {
  if (!io) return;
  const payload = { matchId, seenAt };
  // No zod for AsyncAPI shapes — bail-check the fields.
  if (!matchId || !seenAt) {
    (log || logger).warn({ payload }, 'realtime: messages-seen payload missing fields');
  }
  if (excludeSocket) {
    excludeSocket.to(matchId).emit(EVENTS.MESSAGES_SEEN, payload);
    bumpOutbound(EVENTS.MESSAGES_SEEN);
  }
  if (otherUserId) {
    io.to(otherUserId.toString()).emit(EVENTS.MESSAGES_SEEN, payload);
    bumpOutbound(EVENTS.MESSAGES_SEEN);
  }
};

/**
 * `new-match` — fan out to BOTH participants' personal rooms.
 * Payload shape: `{ match: MatchModel }` per asyncapi.yaml.
 */
const emitNewMatch = (io, { match, log }) => {
  if (!io || !match) return;
  const payload = { match };
  validatePayload(EVENTS.NEW_MATCH, schemas.MatchModel, match, { log });
  const rooms = (match.users || []).map((u) => (u && u._id ? u._id.toString() : String(u)));
  emitToRooms(io, EVENTS.NEW_MATCH, rooms, payload);
};

/**
 * `new-like` — fan out to the recipient's personal room only.
 * Payload shape: `{ fromUserId }`.
 */
const emitNewLike = (io, { fromUserId, toUserId, log }) => {
  if (!io || !toUserId) return;
  const payload = { fromUserId: fromUserId ? fromUserId.toString() : undefined };
  if (!payload.fromUserId) {
    (log || logger).warn({ payload }, 'realtime: new-like missing fromUserId');
  }
  emitToRooms(io, EVENTS.NEW_LIKE, [toUserId.toString()], payload);
};

/**
 * `match-deleted` — fan out to the OTHER participants' personal rooms.
 *
 * Caller passes the full participant list AND the actor; we filter out
 * the actor so they don't get told about their own unmatch.
 */
const emitMatchDeleted = (io, {
  matchId, participantIds, actorId,
}) => {
  if (!io || !matchId) return;
  const actorStr = actorId ? actorId.toString() : null;
  const rooms = (participantIds || [])
    .map((u) => u.toString())
    .filter((u) => u !== actorStr);
  emitToRooms(io, EVENTS.MATCH_DELETED, rooms, { matchId });
};

/**
 * Per-socket error reply — emitted back to the *originating socket only*,
 * not broadcast. Centralized here so the audit grep across `src/` only
 * matches inside this module.
 *
 * The `error` event name is a Socket.IO convention; payload is `{ message }`
 * by current backend usage.
 */
const emitSocketError = (socket, { message }) => {
  if (!socket) return;
  // socket.emit is intentional — these are not broadcasts.
  socket.emit('error', { message });
  bumpOutbound('error');
};

module.exports = {
  EVENTS,
  emitNewMessage,
  emitUserTyping,
  emitMessagesSeen,
  emitNewMatch,
  emitNewLike,
  emitMatchDeleted,
  emitSocketError,
  recordInboundEvent,
};
