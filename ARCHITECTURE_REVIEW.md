Continuing — no tasks needed. Here's the review.

---

# Reverse Match — Architecture Review

## Part 1 — Architecture map

### One-paragraph description

Reverse Match is a two-app system in a single working directory: a Node.js 22 / Express 5 monolith (`backend/`) that serves a REST + Socket.IO API and a Flutter / Riverpod / go_router mobile client (`reverse_match/`). The backend layers routes → controllers → services → Mongoose models, runs on PM2 cluster (`ecosystem.config.js`) with Redis providing rate-limit storage, JWT blacklist, cron leader-election, per-user versioned cache keys, and the Socket.IO multi-instance adapter. Persistence is MongoDB (User, Like, Match, Message, Block, Report, Otp, WebhookEvent), images live on Cloudinary, payments on Stripe (sync webhook), push notifications via Firebase Admin (FCM), email OTP via nodemailer/SMTP, Google login via google-auth-library. Cron jobs (daily boost ladder + hourly expired-boost clear) run in-process under a Redis lock. Realtime chat and notifications happen over Socket.IO with personal rooms (`<userId>`) and match rooms (`<matchId>`). Deployment topology today is `docker-compose` (api + mongo + redis) plus a CI workflow that runs lint, Jest with services, and a docker build smoke test. There are no Kubernetes manifests, no separate worker, no API gateway, no CDN in front of Cloudinary/the API, and no observability beyond Sentry + pino + a `/health` JSON.

### Component diagram (text)

```
                      ┌────────────────────────────────────────────────┐
                      │                Flutter app                     │
                      │  Riverpod state ─ go_router ─ Dio + Socket.IO  │
                      │  Repositories: auth, swipe, queue, (chat/     │
                      │  match/profile via raw Dio in widgets)         │
                      │  Storage: flutter_secure_storage + SharedPrefs │
                      └─────────────────────┬──────────────────────────┘
                                            │  HTTPS + WSS (Bearer JWT)
                                            ▼
                      ┌────────────────────────────────────────────────┐
                      │            (no API gateway / WAF)              │
                      └────────────────────────────────────────────────┘
                                            │
                       ┌────────────────────┴───────────────────┐
                       ▼                                        ▼
       ┌──────────────────────────────┐         ┌──────────────────────────────┐
       │   Express 5 app (PM2 cluster)│         │  Socket.IO (same process,    │
       │   helmet+cors+compression    │         │  same JWT, Redis adapter)    │
       │   global+per-endpoint rate   │◀──────▶ │  rooms: <userId>, <matchId>  │
       │   limiters (Redis backed)    │ same    │  handlers: chat.handler.js   │
       │   routes → controllers →     │ Node    │  emits inline from REST too  │
       │   services → models          │ procs   │                              │
       │   in-process node-cron       │         └──────────────────────────────┘
       └──────────────┬───────────────┘
                      │   Mongoose 9, sync writes
                      ▼
       ┌──────────────────────────────┐    ┌──────────────────────────────┐
       │   MongoDB (single replica    │    │   Redis 7                    │
       │   set OR standalone — toggle │    │   - rate-limit store         │
       │   via MONGO_TRANSACTIONS_    │    │   - cache:feed,exclude,ideal │
       │   ENABLED)                   │    │   - JWT blacklist            │
       │   collections: users, likes, │    │   - banned:<userId>          │
       │   matches, messages, blocks, │    │   - lock:job:*               │
       │   reports, otps, webhook-    │    │   - socket.io pub/sub        │
       │   events                     │    │   - versioned cache counters │
       └──────────────────────────────┘    └──────────────────────────────┘

                External services (over HTTPS, fire-and-mostly-forget):
                ┌─────────────┐ ┌─────────────┐ ┌─────────────┐ ┌─────────────┐
                │  Cloudinary │ │   Stripe    │ │   Firebase  │ │    SMTP     │
                │  (photos +  │ │  Checkout + │ │  Admin /    │ │  (OTP mail) │
                │   selfie,   │ │  webhook    │ │  FCM push   │ │             │
                │   moderation│ │  sync to    │ │             │ │             │
                │   add-on)   │ │  Mongo)     │ │             │ │             │
                └─────────────┘ └─────────────┘ └─────────────┘ └─────────────┘

                                External SDK in mobile only:
                                ┌─────────────┐ ┌─────────────┐
                                │  google-    │ │  Geolocator │
                                │  sign-in    │ │  + Geocoding│
                                └─────────────┘ └─────────────┘
```

### Where state lives

| State | Location | Owner / lifetime |
|---|---|---|
| User identity, profile, photos array, refresh sessions, fcmTokens, selfie review status, boost level/expiry, daysWithoutMatch, banned flag | Mongo `users` | authoritative |
| Likes (pending/accepted/rejected/skipped), unique `{fromUser,toUser}` | Mongo `likes` | authoritative |
| Matches (sorted pair, unique compound on `users.0`/`users.1`) | Mongo `matches` | authoritative |
| Messages (`{matchId, sender, text, seen, seenAt, createdAt}`) | Mongo `messages` | authoritative |
| Blocks, Reports, OTP hashes, processed Stripe events | Mongo (`blocks`, `reports`, `otps`, `webhookevents`) | authoritative |
| Photos & selfies | Cloudinary, referenced by `{url, publicId}` in `users.photos` / `users.selfiePhoto` | best-effort delete via service; orphans logged but never reaped |
| FCM tokens (multi-device, bounded slice -10) | embedded in `users.fcmTokens` | upserted on login/refresh, pruned when FCM reports invalid |
| Feed cache, exclude cache, ideal-match cache | Redis `feed:<userId>:<ver>:<limit>`, `exclude:<userId>:<ver>`, `ideal:<userId>:<limit>` | TTL 120s / 300s / 24h, busted via `ver:<ns>:<id>` INCR |
| Cache version counters | Redis `ver:feed:<userId>`, `ver:exclude:<userId>` | INCR on write; falls back to constant "v1" when Redis is down |
| JWT blacklist (per-jti) and banned-flag (per-user) | Redis `blacklist:<jti>`, `banned:<userId>` | TTL = access-token lifetime |
| Rate-limit counters | Redis `rl:<bucket>:*` (auth / otp / like / message / global / mutation / undo) | windowed |
| Cron leader lock | Redis `lock:job:dailyBoost`, `lock:job:clearExpiredBoosts` | 1h / 10min TTL |
| Socket.IO pub/sub fan-out | Redis pub/sub via `@socket.io/redis-adapter` | runtime |
| Refresh-token family (multi-device) | Mongo `users.refreshSessions[]` (jti + sha256 hash + expiry + deviceId) | rotated per refresh, capped at 10 |
| Auth state, last-known user gender, dummy access token | Flutter `flutter_secure_storage` + `shared_preferences` | client lifetime |
| File system | only PM2 log files under `backend/logs/` | dev/local |

### Layering and where boundaries leak

Backend's nominal layering is sound: `routes → controllers (catchAsync) → services → models`. Cross-cutting helpers live in `utils/` (`AppError`, `cache`, `withTransaction`, `userProjection`, `token`, `otp`, `logger`). Concrete leaks observed:

- **Controllers reach into models and emit sockets.** `match.controller.deleteMatch` does `Match.findById` directly to look up users for fan-out; `message.controller.markSeen` requires `Match.findById` from inside the controller; `swipe.controller.like`, `match.controller.deleteMatch`, `message.controller.sendMessage` all reach for `req.app.get('io')` and emit events from the controller. There is **no event bus** between business logic and the realtime layer — every emit site is hand-coded, with shape-equivalent code duplicated between `chat.handler.js` and the REST controllers (the `new-message` payload is built twice; `messages-seen` is fan-out twice).
- **`upsertFcmToken` is called from the auth controller**, not the auth service. Side-effect plumbing has leaked across the seam.
- **Cron is initialized in `server.js`** (`require('./src/jobs/dailyBoost.job')`) and runs in-process under PM2 cluster; there is no `worker` boundary, no job abstraction, and no scheduler module distinguishing "scheduled work" from "deferred work" — just two `cron.schedule` calls in one file.
- **Idempotency for Stripe** is enforced in `boost.service.handleStripeWebhook` only; there is no general idempotency middleware or table for the public mutation endpoints (`/swipe/like`, `/queue/accept/*`, `/messages`).
- **Validators reach into `User.enums`** to import enum constants; constants of truth are duplicated again in `idealMatch.service` (e.g. `DATING_INTENTIONS`, `RELATIONSHIP_TYPES`, `EXERCISE`, `CHILDREN`, `FAMILY_PLANS`) and again in Flutter `UserModel` (free-form strings). Three sources of the same taxonomy.
- **Frontend has only three repos** (`auth_repository.dart`, `swipe_repository.dart`, `queue_repository.dart`). Chat (`chat_screen.dart`), matches (`matches_screen.dart`), profile, boost, and onboarding screens use `ref.read(dioProvider)` and call `dio.get/post(ApiEndpoints.x)` directly from widgets — the repository pattern only exists for a third of the API surface.
- **Frontend has no domain layer**: there is no `MatchService`, `ChatService`, etc; state notifiers in `presentation/providers/` consume repositories where they exist, and Dio everywhere else.
- **`auth_provider.checkAuthStatus`** rebuilds a stub `UserModel(id: userId, gender: gender)` from secure storage instead of fetching `/profile` — the auth state's notion of "user" is partial and the router's `user.isProfileComplete && user.gender == null` redirect depends on these defaults.
- **`Account` and `safety` routes are mounted at `/` with `auth`** in `routes/index.js` (`router.use('/', auth, safetyRoutes)` twice) so their internal paths must be globally unique strings — a router-namespace leak that will bite the next time someone adds a new route family.
- **Express `req.cleanQuery` is used in controllers** but the source (`sanitize` middleware) is generic; the boundary between transport sanitation and controller parsing is opaque.

---

## Part 2 — Architectural flaws

Severity: **Critical / Major / Minor**. I am *not* re-listing line-level P0/P1/P2 fixes already done.

### 1. Layering & module boundaries

**1.1 — No event bus; socket fan-out is duplicated across controllers and chat handler.** Severity: **Major.**
**Where**: `src/controllers/swipe.controller.js:25-31`, `src/controllers/match.controller.js:18-29`, `src/controllers/message.controller.js:28-44, 51-69`, `src/socket/chat.handler.js:62-83, 110-141`. **What**: every business event (`new-like`, `new-match`, `new-message`, `messages-seen`, `match-deleted`) is emitted at the call site by importing `req.app.get('io')` directly inside the controller (REST) or by hand-emitting in the socket handler. Match-room and personal-room fan-out is duplicated between the HTTP `sendMessage` controller and the socket `send-message` handler. **Why it bites**: every future feature (super-like, boost activated, profile-viewed, video-call ring) bolts a new pair of emit sites onto every controller; an event-shape change requires hunting every emit; tests have to mock `req.app.get('io')` per controller. On-call cannot grep "where do `new-message` events come from"; there are two answers. **Fix shape**: a `realtime/events.js` module exposing `emitNewMessage(io, {matchId, message, users})`, `emitNewLike(io, {toUserId, fromUserId})`, etc.; services call these via DI (or via a domain-event emitter), controllers don't touch `io`.

**1.2 — Frontend repository pattern is implemented for ~⅓ of the API surface.** Severity: **Major.**
**Where**: only `features/auth/data/auth_repository.dart`, `features/home/data/swipe_repository.dart`, `features/home/data/queue_repository.dart` exist. Chat (`features/chat/presentation/screens/chat_screen.dart:60-117`), matches (`features/match/presentation/screens/matches_screen.dart:53-101`), profile edit, boost, onboarding all do `final dio = ref.read(dioProvider); dio.get/post(ApiEndpoints.x)` straight in the widget/notifier. **What**: the data layer doesn't exist for half the features, so error handling, retries, response-shape mapping, and DTO→model conversion are reinvented per screen. **Why it bites**: every contract drift (e.g., the backend `queue.service.accept` now returns the populated match doc *directly* but `queue_repository.dart:36` reads `response.data['match']`) lands as a runtime bug on a single screen instead of a single test against a single repository. Adding offline support, request deduping, or a swap to GraphQL/openapi-codegen will require touching every widget. **Fix shape**: one repository per feature (`MatchesRepository`, `ChatRepository`, `ProfileRepository`, `BoostRepository`, `SafetyRepository`, `AccountRepository`) returning `ApiResult<T>` or sealed `AsyncValue<T>`; widgets read providers only.

**1.3 — No shared frontend↔backend contract.** Severity: **Critical.**
**Where**: backend Mongoose enums (`models/User.js:32-62`), validators (`validators/profile.validator.js`), Flutter `UserModel`/`MatchModel`/`LikeModel`/`MessageModel`, and the third copy inside `services/idealMatch.service.js:11-55`. **What**: no OpenAPI spec, no codegen, no shared types/protobuf, no JSON-schema. Spec is a Markdown file (`BACKEND_API.md`) the human keeps in `Downloads/`. **Why it bites**: this is exactly what produced the queue-accept shape divergence; the Flutter `UserModel` silently coerces missing fields to defaults so contract drift is invisible until QA. There is no compile-time guarantee that the field a controller projects in `userProjection.js` matches the field the Flutter app reads. At 100k users, this becomes the single biggest source of regression. **Fix shape**: adopt OpenAPI 3.1 generated from JSDoc or written by hand and committed; generate Dart models with `openapi-generator` or `chopper`; generate Joi validators or zod schemas server-side from the same spec.

**1.4 — Cron / deferred work has no abstraction; in-process under PM2 cluster.** Severity: **Major.**
**Where**: `src/jobs/dailyBoost.job.js` is 124 lines and contains: (a) a Redis lock helper, (b) the daily ladder cron, (c) the hourly expired-boost cron. The future image-reaper, selfie-review-reminder, retention-purge, and any analytics ETL will all pile into this file or sit next to it. **What**: no queue abstraction, no retry policy, no dead-letter, no job-history audit, no rate-limited backpressure for slow operations, no separation between "scheduled" and "deferred". **Why it bites**: at 100k users, the daily-boost `$inc` over all active males will start to take long enough that cluster-wide locking on Redis with a 1h TTL is fragile; the orphan-image reaper has nowhere to live; the Stripe webhook handler is synchronous (boost activation happens inside the HTTP request — see `boost.service:144-152`) so a Mongo blip during a webhook = 5xx back to Stripe = duplicate processing risk. **Fix shape**: introduce BullMQ on top of the existing Redis, give it producers from services (`scheduler.enqueue('boost.activate', { userId, tier, durationMinutes }, { jobId: event.id })`), give it a dedicated `worker` process in `ecosystem.config.js`.

**1.5 — Controllers do incidental DB work.** Severity: **Minor.**
**Where**: `match.controller.deleteMatch` (`Match.findById` for fan-out), `message.controller.markSeen` (second `Match.findById` after the service), `match.controller` mounts `Match.findById` inline pre-deletion. **What**: controllers re-query because the service doesn't return enough context. **Why it bites**: makes controllers harder to test in isolation; encourages more drift. **Fix shape**: services return `{result, ctx}` where ctx contains everything the realtime emitter or controller needs.

**1.6 — Account/safety routes mounted at `/` instead of a named prefix.** Severity: **Minor.**
**Where**: `src/routes/index.js:34-35`. **What**: `router.use('/', auth, safetyRoutes)` and same for account. Internal paths in `safety.routes.js` and `account.routes.js` must remain globally unique forever. **Why it bites**: a `/report` route inside safety and a future `/report-bug` route inside another module would silently collide. **Fix shape**: mount under `/safety` and `/account` like everyone else.

### 2. Domain model coherence

**2.1 — Three sources of truth for taxonomies.** Severity: **Major.**
**Where**: `models/User.js:32-62` declares enums; `validators/profile.validator.js:22-26` redeclares EXERCISE_VALUES and ZODIAC_VALUES; `services/idealMatch.service.js:11-55` redeclares everything plus TOP_INTERESTS and TOP_LANGUAGES; Flutter `UserModel` treats them as free strings. **Why it bites**: adding `vegetarian` to a vice or `non_binary` to a gender requires editing 3 files plus a Flutter mapping; the scoring vector silently includes/excludes things based on a list nobody owns. **Fix shape**: a single `src/domain/taxonomies.js` (or, with OpenAPI, an `enums.yaml`) — model, validator, scorer, and frontend codegen all import from one place.

**2.2 — Light frontend models lose information.** Severity: **Minor.**
**Where**: `shared/models/user_model.dart:76-124`. **What**: fields are typed but enums are free-form `String?` (children, familyPlans, datingIntentions, relationshipType, vices.*), so invalid values from a future backend version are silently accepted. **Why it bites**: bugs land at the rendering layer instead of the parsing layer. **Fix shape**: enums on the client OR build-time generation from the OpenAPI spec.

**2.3 — `Match.users` is a flat array; participant order, presence, and pair-uniqueness are co-enforced by a `pre-save` hook and a compound index.** Severity: **Minor (reviewed).**
**Where**: `models/Match.js`. **Reviewed and acceptable** — pair sort + `uniq_user_pair` is a sound MVP pattern. Long-term, switch to explicit `{userA, userB}` columns to remove the implicit ordering, especially if you ever need group matches.

**2.4 — `daysWithoutMatch` is a counter on `User`, not an event log.** Severity: **Minor.**
**Where**: `User.daysWithoutMatch`, cron does `$inc` daily. **What**: there is no record of "last match date"; recomputing the counter or auditing why a user is at gold-boost is impossible. **Why it bites**: at scale, you'll want to ask "show me users who hit gold-auto in the last week" — currently you can't. **Fix shape**: store `lastMatchedAt`, derive `daysWithoutMatch` on read (also lets you remove the daily-batch update entirely).

### 3. Cross-cutting concerns

**3.1 — No request-correlation ID.** Severity: **Major.**
**Where**: `src/app.js`, `src/middleware/error.middleware.js`. **What**: morgan logs include method/url/status; pino logs include `err`; nothing carries a request-id across the request, the socket events fanned out from it, the queue job it enqueues, or the third-party call it made. Sentry sees the exception but doesn't see "this is the same request that emitted these 3 socket events". **Why it bites**: every on-call investigation that involves "user X reports their match disappeared" requires manually correlating logs by timestamp + userId. **Fix shape**: a `requestId.middleware` setting `X-Request-ID`, propagated through pino's child logger and into job enqueues and socket emits.

**3.2 — No idempotency keys on public mutation endpoints.** Severity: **Major.**
**Where**: `POST /swipe/like`, `POST /queue/accept/:id`, `POST /messages`, `POST /report`, `POST /block`. **What**: the only idempotency in the system is the Stripe-event upsert. Mobile clients on flaky 4G will routinely retry `POST /messages` and `POST /swipe/like` — Like has a `{fromUser,toUser}` unique index so it's safe, but Messages will store duplicates if the client retries after a 200 was lost. **Why it bites**: chat shows ghost duplicates after lossy networks; users blame the app, not their network. **Fix shape**: an idempotency middleware reading `Idempotency-Key` header, persisting `{key, requestHash, responseSnapshot}` in a Redis TTL.

**3.3 — Inconsistent error-response shape for Joi.** Severity: **Minor.**
**Where**: `error.middleware.js` handles Mongoose ValidationError but Joi validators (in `validate.middleware.js`) produce their own shape. The frontend `auth_repository.dart:28` reads `e.response?.data?['error']?['message']` — works for the AppError path; not guaranteed for Joi-rejected requests. **Fix shape**: wrap Joi errors in `AppError` consistently.

**3.4 — No feature-flag system.** Severity: **Minor.**
**Where**: feature gates today are environment booleans (`MONGO_TRANSACTIONS_ENABLED`, `CLOUDINARY_MODERATION`, `JWT_ACCESS_EXPIRY`). **Why it bites**: rolling out ideal-match v2 or a new boost tier requires a redeploy. **Fix shape**: a `featureFlags.js` module reading from Redis/Mongo with a 60s memo, exposed to the client via `/config`.

**3.5 — In-process ban cache is per-PM2-process.** Severity: **Minor.**
**Where**: `auth.middleware.js:9-28`. **What**: a 30s in-process Map of banned-state. With PM2 cluster mode (default `instances: 'max'`), each Node process has its own map, so a freshly-banned user is rejected by one worker but allowed by another for up to 30s. The Redis flag is the authoritative path; cache only matters when Redis is unreachable. **Reviewed and acceptable** as a short-window fallback but worth a note in the ADR — it intentionally lags by 30s.

### 4. State management — Mongo / Redis

**4.1 — `Like` table mixes likes and skips, never expires.** Severity: **Major.**
**Where**: `models/Like.js`, `swipe.service.skip`. **What**: every "swipe left" inserts a permanent doc with `status: 'skipped'`. At 100k DAU each viewing 50 cards/day = 5M rows/day in the `likes` collection, indefinitely. The unique `{fromUser,toUser}` index works for the swipe semantics but the table grows without bound, and the `feed.getFeed` `Like.find({fromUser:userId}).distinct('toUser')` query has to walk all of it. **Why it bites**: feed-exclude computation gets slower over time; Mongo working set bloats. **Fix shape**: TTL on skipped rows (Mongo TTL index on `expiresAt` with a 30-day default for skips, never for accepted), or move skips to a separate collection with TTL, or store exclude-set as a Redis Bloom filter.

**4.2 — Feed cache only ever caches the first page with no filters.** Severity: **Minor (reviewed).**
**Where**: `swipe.service:52-56, 254-257`. **Reviewed and acceptable** — caching paginated cursor pages with versioned invalidation gets dangerous fast; the current scheme correctly bypasses cache on any filter or cursor. Be aware it means the second and subsequent feed pages always hit the aggregation.

**4.3 — Ideal-match computation is on-request and unbounded.** Severity: **Major.**
**Where**: `services/idealMatch.service.js:240-335`. **What**: every `GET /ideal-match` does a `$geoNear` for up to 500 candidates, encodes each into a ~150-element feature vector in JS, runs cosine on every pair, sorts, and caches for 24h. With 100k users this is 500 vector encodes per request, each ~150 doubles, all in-process. **Why it bites**: at 1M users the candidate pool inside max-distance grows; at 100k DAU each requesting once a day = the cache hits are good but cold-start (or any profile edit that invalidates the cache) thunders into the API. **Fix shape**: precompute feature vectors per user (store in Mongo or Redis), nightly job; on-request reduces to vector-vs-N dot-products; or move scoring to a Python worker reading from a vector index (pgvector / Mongo Atlas vector search).

**4.4 — `getMatches` aggregation does two `$lookup` per match plus a third for users.** Severity: **Minor.**
**Where**: `services/match.service.js:18-97`. **What**: three lookups per match. For a user with 200 matches and `limit=20`, the aggregate is fine, but the unread-count lookup re-counts every page. **Fix shape**: denormalize `lastMessage` and `unreadCount` onto `Match` (write-through on `sendMessage` and `markSeen`); the aggregation then reduces to one lookup for users.

**4.5 — `User.fcmTokens` is unbounded by deviceId but bounded to 10 by slice.** Severity: **Minor (reviewed).**
**Where**: `notification.service.upsertFcmToken`. **Reviewed and acceptable** — `$pull` by deviceId then `$push` with `$slice: -10` is correct.

### 5. Realtime architecture

**5.1 — Socket events are scattered, payloads are not typed, and no schema is enforced.** Severity: **Major.** *(Same root cause as 1.1.)* Add: there's no schema for `join-room`, `send-message`, `typing-start`, etc; the handler does ad-hoc validation per event (`if (!matchId || typeof matchId !== 'string') return;`).

**5.2 — `messages-seen` and `new-message` emitted twice (to room + to each personal room).** Severity: **Minor.**
**Where**: `socket/chat.handler.js:73-83, 121-138`, `controllers/message.controller.js:31-40, 53-68`. **What**: the chat room contains both participants when both have the chat open; the code then *also* emits to each `<userId>` room. A participant currently viewing the chat will receive `new-message` twice. The frontend de-dupes by message ID, but bandwidth is doubled and ordering races become possible. **Fix shape**: emit `new-message` only to personal rooms; have the chat screen subscribe to its participant's personal room and filter by `matchId`.

**5.3 — No reconnection state reconciliation.** Severity: **Major.**
**Where**: `core/socket/socket_service.dart`. **What**: on reconnect, the client re-joins via socket but does not re-fetch missed messages, matches, or likes; it relies on the user navigating away and back. **Why it bites**: classic "I closed my phone for an hour and don't see new messages until I pull-to-refresh." **Fix shape**: on reconnect, the client emits `since:<lastEventTs>` and the server replays a bounded backlog from Mongo; or simpler, the client refetches `/matches` and the open `/messages/:id` on reconnect.

**5.4 — Socket auth has no rate-limit on connect attempts.** Severity: **Minor.**
**Where**: `socket/index.js:51-89`. **What**: HTTP routes are rate-limited; WS handshakes aren't. **Why it bites**: bot can hammer `io.connect` with bogus tokens; each attempt does a Redis lookup + a Mongo `findById`. **Fix shape**: per-IP connect rate limiter in front of the handshake.

**5.5 — `mark-seen` re-queries the Match doc inside the socket handler after the service already did.** Severity: **Minor.**
**Where**: `socket/chat.handler.js:117-138`. **Same root cause as 1.1.**

### 6. Background work

**6.1 — Stripe webhook activates boosts synchronously inside the HTTP handler.** Severity: **Major.**
**Where**: `services/boost.service.handleStripeWebhook:144-152`. **What**: Mongo write happens inline; if Mongo is slow Stripe will time out and retry, and the upsert dedup is the only thing keeping double-activation from happening. The webhook is also synchronous about *all* event types (only `checkout.session.completed` is handled today, but future Stripe events like `charge.refunded` will pile in). **Fix shape**: webhook handler validates signature, persists raw event (already done), enqueues a `boost.process` job, returns 200. Job worker performs the activation with retries.

**6.2 — Image-reaper is a TODO comment.** Severity: **Major.**
**Where**: `services/profile.service:185-188`. **What**: failed Cloudinary deletes are logged. There is no `pendingImageDeletes` collection, no retry job, no observability on the orphan rate. **Why it bites**: directly costs money (Cloudinary storage) and exposes deleted-account PII if the deletion ever fails silently. **Fix shape**: see 1.4 — a `media.delete` job in BullMQ.

**6.3 — Cron leadership relies on Redis being healthy.** Severity: **Minor.**
**Where**: `jobs/dailyBoost.job.js:15-42`. **What**: the fallback to `NODE_APP_INSTANCE === '0'` is correct for PM2 cluster, but PM2 doesn't relabel instances when one dies — if instance 0 crashes, the daily job stops running until restart. **Reviewed and acceptable for v1** with PM2 auto-restart, but the migration to a worker service eliminates this.

### 7. Frontend architecture

**7.1 — Auth-state's `UserModel` is a stub on cold start; provided by storage, not API.** Severity: **Major.**
**Where**: `features/auth/presentation/providers/auth_provider.dart:26-44`. **What**: `checkAuthStatus` constructs `UserModel(id: userId, gender: gender)` from secure storage; almost every field is empty/default; `isProfileComplete` defaults to `false`; the router uses `!user.isProfileComplete && user.gender == null` as the onboarding redirect. **Why it bites**: a returning user with a complete profile gets stuck momentarily on onboarding screens during the cold-start race until /profile loads, and there is no /profile load. **Fix shape**: `checkAuthStatus` should `await profile.repository.getMe()` and only emit `AuthAuthenticated` once the full user is loaded; loading state stays on splash.

**7.2 — `dio_client.dart` token refresh has a thundering herd risk.** Severity: **Major.**
**Where**: `core/network/dio_client.dart:38-82`. **What**: every 401 launches its own refresh request via a *new* Dio instance. If 5 widgets hit a 401 simultaneously (common after wake-from-sleep), 5 concurrent refresh calls fire, four of which will fail because the first one rotated the refresh token. The catch then clears tokens, logging the user out. **Fix shape**: a single in-flight refresh `Future` cached on the interceptor; concurrent 401s await the same future.

**7.3 — Riverpod providers are instantiated ad-hoc inside notifiers via `ref.read`.** Severity: **Minor.**
**Where**: `auth_provider.dart:11-15`, repository providers. **Reviewed and acceptable** but they don't expose any `ref.watch` for hot-reload of the Dio client when storage tokens change; today this is fine because the interceptor reads storage inline.

**7.4 — No offline support.** Severity: **Minor.**
**Where**: `core/network/connectivity_service.dart` only displays an offline banner. The app is purely online. **Fix shape**: a future v2 concern; not for launch.

**7.5 — `flutter/` SDK is vendored at the repo root.** Severity: **Critical.**
**Where**: `flutter/` is a full Flutter SDK checked in alongside `backend/` and `reverse_match/`. **What**: pinning the SDK by-vendoring bloats the repo, breaks every contributor's local fvm/flutter version, and forces multi-GB diffs into git. **Why it bites**: clones take minutes, IDE indexing breaks, CI cache is poisoned. **Fix shape**: `.gitignore` it; use `fvm`/`asdf` with an `.fvmrc`/`.tool-versions` in `reverse_match/`.

**7.6 — Build flavors implemented via dart-define + dotenv but only minimally.** Severity: **Minor.**
**Where**: `lib/main.dart:21-27`. The `.env`, `.env.production`, `.env.staging` files are loaded by `flutter_dotenv` based on `String.fromEnvironment('ENV')`. **Reviewed and acceptable** for now; if you need different package IDs / app icons per env you'll need real flutter flavors.

### 8. API contract management

**8.1 — Contract lives in a Markdown file outside the repo (`Downloads/BACKEND_API.md`).** Severity: **Critical.**
**Where**: per the user, `C:\Users\agraw\Downloads\BACKEND_API.md`. **What**: the source of truth for the API is not in version control, not under code review, not consumable by tools. Comments in the backend say "spec §3" repeatedly. **Why it bites**: any future engineer who joins the project cannot discover what `/matches` returns without reading both the backend service and the spec doc; reviewers cannot catch contract drift in PRs. **Fix shape**: commit `docs/api/openapi.yaml` into the repo; generate Dart models and Joi validators from it; CI fails on undocumented endpoints.

**8.2 — No contract tests.** Severity: **Major.**
**Where**: integration tests verify the backend; no test verifies that the Flutter `UserModel.fromJson` accepts what `getProfile` produces. **Fix shape**: Pact contract tests, or a shared `fixtures/` JSON that both backend integration tests and Flutter widget tests load.

### 9. Configuration & environments

**9.1 — Env var sprawl with no schema validation.** Severity: **Minor.**
**Where**: `src/config/index.js` parses 30+ vars with `parseInt`/fallbacks; required list is only `MONGO_URI`, `JWT_ACCESS_SECRET`, `JWT_REFRESH_SECRET`. Missing `STRIPE_*` silently degrades (returns `url: ''` from purchase). Missing `CLOUDINARY_*` would crash on first upload. Missing `FIREBASE_*` silently disables push. **Reviewed and partly acceptable** (the "fail soft in dev" pattern is intentional) but production should fail loudly if Stripe/Cloudinary/Firebase aren't configured. **Fix shape**: per-env required-vars list, Joi-validated at boot.

**9.2 — `MONGO_TRANSACTIONS_ENABLED` is a runtime toggle for correctness.** Severity: **Major.**
**Where**: `config/index.js:80-82`, `utils/withTransaction.js`. **What**: when transactions are unavailable, multi-doc cascades (account delete, block, accept-like, delete-match) run sequentially with a log warning. **Why it bites**: a partial failure in production (network blip between two writes) leaves the database inconsistent. The fallback exists for local dev (standalone Mongo). **Fix shape**: in production, transactions must be ON and `MONGO_URI` must point at a replica set — enforce at boot, refuse to start if not.

**9.3 — Secrets in `.env` and `firebase-service-account.json` in repo root.** Severity: **Critical.**
**Where**: `backend/firebase-service-account.json` (in `ls` output above). **What**: Firebase admin private key in the repo. Even if `.gitignore`d, a stray `git add -A` lands it. **Fix shape**: use a secret manager (Vault/AWS Secrets Manager/GCP Secret Manager); CI pulls at deploy; never commit; rotate the key now if it was ever pushed.

### 10. Testing pyramid

**10.1 — Coverage threshold dropped 70 → 60 to keep CI green.** Severity: **Major (already flagged).** This is a debt marker; the gap is in transaction helpers, refresh paths, gender DB checks. **Fix shape**: don't lower the bar — write the missing tests; raise back to 70+.

**10.2 — No Flutter tests beyond the default smoke.** Severity: **Major.**
**Where**: `reverse_match/test/`. **What**: no widget tests, no provider tests, no goldens. **Why it bites**: every contract drift, every routing-redirect regression, every Riverpod state machine bug ships untested. **Fix shape**: at minimum, provider/notifier unit tests, repository tests mocking Dio, and a goldens pass for the home / matches / chat screens.

**10.3 — No load / soak tests.** Severity: **Major.**
**Where**: nowhere. **What**: the PM2 config and Mongo pool size say "1500 concurrent users" but no test ever validates that. **Fix shape**: k6 or Artillery script: 1k concurrent socket connections, 100 msgs/sec, 50 feed/sec; run on a staging Atlas M10.

**10.4 — Integration tests are good (one file per route family).** **Reviewed and acceptable.**

### 11. Observability & operations

**11.1 — `/health` is depth-1; no metrics, no traces.** Severity: **Major.**
**Where**: `src/app.js:89-134`. **What**: health checks Mongo + Redis; no Prometheus `/metrics`, no OpenTelemetry tracing, no socket-connection gauge, no per-endpoint latency histogram. Sentry catches exceptions but says nothing about latency regressions. **Fix shape**: `prom-client` exposing default metrics + business gauges (`socket_connected_count`, `feed_request_duration_ms`, `boost_active_count`, `cron_last_run_ts`); a Grafana board; alerts on p99 latency, error rate, and cron heartbeat absence.

**11.2 — No structured business logs.** Severity: **Minor.**
**Where**: pino is structured but most logs are `'user banned by admin'` with `userId/adminId`. Good. **Reviewed and acceptable** — formalize a small set of event names (`auth.signup`, `boost.activated`, `match.created`, `account.deleted`) and grep on those for funnel/ops dashboards.

**11.3 — No runbook.** Severity: **Major.**
**Where**: nowhere. **What**: "Mongo is at 90% disk", "Redis is unreachable", "Stripe webhook returning 4xx", "FCM token bounce rate >5%" — no documented response. **Fix shape**: `docs/runbooks/*.md`, one per top-3 alert.

### 12. Deployment & infra

**12.1 — No CD pipeline.** Severity: **Critical.**
**Where**: `.github/workflows/ci.yml`. **What**: CI runs lint, tests, docker build smoke. Nothing pushes to a registry, no environment deploy. Production deploy is presumably manual `pm2 start` on a VM. **Fix shape**: a `cd.yml` that pushes images to GHCR/ECR on `main`, deploys to staging automatically, gates production on a manual approval.

**12.2 — Docker-compose is single-host.** Severity: **Major.**
**Where**: `docker-compose.yml`. **What**: no load balancer, no TLS, no PM2 cluster (the `api` service is 1 container). For >1k concurrent users the next step is K8s or ECS with a service per backend and a managed Mongo/Redis. **Fix shape**: pick the target (K8s vs ECS vs Cloud Run) — see Part 4 — and write the manifests / Terraform.

**12.3 — No Mongo migrations.** Severity: **Major.**
**Where**: nowhere. **What**: schema changes today rely on Mongoose's "make any field optional" forgiveness. `User.refreshSessions` was added; there is no migration that backfills it for existing users, only the read-time backward-compat code in `authService.refreshTokens`. **Fix shape**: `migrate-mongo` or `mongoose-migrate` with versioned migrations in `backend/migrations/`; CI runs them dry against a staging dump.

**12.4 — No CDN in front of Cloudinary URLs or the API.** Severity: **Minor.**
**Where**: profile photos render directly from `result.secure_url`. **Reviewed and acceptable** — Cloudinary is itself a CDN; just make sure the transformation URLs are stable so HTTP cache works.

### 13. Security architecture

**13.1 — No defense against credential-stuffing-style OTP enumeration.** Severity: **Minor.**
**Where**: `auth.service.sendOtp`. **What**: rate limits exist, but there's no per-IP global throttle separate from per-email. A botnet hitting `/auth/signup` with different IPs and emails can spam your SMTP and probe email validity by timing. **Fix shape**: CAPTCHA on first-time email, or hCaptcha on Tor exits.

**13.2 — Selfie review pipeline is half-built.** Severity: **Major.**
**Where**: `profile.service.uploadSelfie:215-242`, `User.selfieReviewStatus`. **What**: selfie state machine is `none → pending → approved/rejected` but no admin endpoint or UI exists. `isVerified` is permanently false until someone hand-runs a Mongo update. **Why it bites**: in a dating-app threat model, unverified profiles are a known abuse vector; until there is an approval queue, the badge never lights up. **Fix shape**: admin endpoints for queue + approve/reject + add a TODO acceptance criterion: "30% of users have isVerified=true within 7 days of signup."

**13.3 — No right-to-be-forgotten compliance trail.** Severity: **Major.**
**Where**: `services/account.service.deleteAccount`. **What**: the cascade is excellent — Mongo + Cloudinary + Redis + socket disconnect. There is no audit log of the deletion (who, when, from where), no soft-delete grace period (GDPR allows immediate, but a 30-day grace is industry standard for accidental clicks), no export-my-data endpoint. **Fix shape**: a `DeletionRequest` audit collection; a `GET /account/export` returning a ZIP.

**13.4 — Helmet + CORS + sanitize + helmet are all on; OWASP top 10 baseline is good.** **Reviewed and acceptable.**

**13.5 — JTI-linkage gap is already known (carried forward).** Out of scope per the brief.

### 14. Cost & scaling

**14.1 — 10k users (single backend instance, PM2 cluster, single Mongo, single Redis).** Should work. Bottleneck: ideal-match aggregation on cold cache; daily-boost cron over ~5k male users completes well within the batch budget. Recommendation: just ensure Atlas M10 + Redis 256MB + a CDN/TLS in front.

**14.2 — 100k users.** Will start to break at:
- Feed-exclude query (`Like.find({fromUser}).distinct('toUser')`) — see 4.1; tens of thousands of skipped rows per user. **Mitigation**: TTL on skipped likes, Redis bloom filter.
- Daily-boost cron — `$inc` on 50k male docs in batches of 5k is 10 batches per night, fine; but the next batch of background work (image reaper, retention) needs the queue.
- Ideal-match scoring — see 4.3; cache hits stay good but cold-start storm on the 24h cache rollover hour will spike CPU. **Mitigation**: stagger TTLs, precompute nightly.
- Socket fan-out — Redis adapter handles it but the Mongo Match.findById for fan-out (4.4) starts to hurt. **Mitigation**: cache the participant list.
- Storage: at 6 photos per user × 800KB avg × 100k = ~480GB on Cloudinary. Costs become real. **Mitigation**: aggressive transformations; require WebP.

**14.3 — 1M users.** Architecture has to change:
- Mongo sharding by `users._id`; matches and messages co-sharded on `matchId`.
- Read replicas for feed / queue queries.
- Move ideal-match to a dedicated worker reading from a vector index (Mongo Atlas Vector Search, pgvector, or Pinecone).
- Split: `api`, `worker`, `realtime` services in K8s.
- Per-region deployment with sticky-session WS routing.
- Object-store offload for photo originals; keep Cloudinary only as CDN/transform.

### 15. Repo & developer experience

**15.1 — Polyrepo vs monorepo decision is implicit and inconsistent.** Severity: **Major.**
**Where**: `backend/`, `reverse_match/`, and vendored `flutter/` all live in one git repo. **What**: there's no monorepo tooling (no nx, turborepo, pnpm workspaces, melos), no shared package, no shared CI matrix, no shared ESLint/dart-lint config. So it acts like a polyrepo without the isolation. **Why it bites**: a backend-only PR runs Flutter changes through nothing; a Flutter PR has no awareness of API drift. **Fix shape**: pick a side. Either (a) embrace monorepo: melos + a shared `packages/api-types` (generated from OpenAPI); (b) split into two repos with the OpenAPI spec as the contract artifact between them.

**15.2 — Pre-commit hooks absent.** Severity: **Minor.**
**Where**: no husky / lefthook / lint-staged. **Fix shape**: husky + lint-staged for `eslint --fix` + `flutter format`.

**15.3 — No CONTRIBUTING.md, no ADR directory.** Severity: **Minor.**
**Fix shape**: `docs/adr/0001-mongo-vs-postgres.md`, etc.

---

## Part 3 — Prioritized improvement plan

### Phase 0 — Foundations to unblock everything else

| # | Title | Files / modules | Lead agent | Followers | Effort | Deps | Acceptance |
|---|---|---|---|---|---|---|---|
| **0.1** | Adopt OpenAPI 3.1 spec as single source of truth | new `docs/api/openapi.yaml` (from `Downloads/BACKEND_API.md`), commit to repo | `design-architect` | `backend-engineer`, `frontend-ui-developer` | L | none | OpenAPI lints clean; every existing endpoint and Socket.IO event documented; CI fails on undocumented routes via spectral |
| **0.2** | Generate Dart models + a Dio client from OpenAPI | `reverse_match/lib/api/` (generated), wire into existing repositories | `frontend-ui-developer` | `design-architect` | M | 0.1 | `flutter pub run build_runner` produces models; `UserModel` is gone in favor of generated; `flutter test` passes |
| **0.3** | Generate Joi validators or migrate to zod schemas from OpenAPI | `backend/src/validators/` becomes generated | `backend-engineer` | `design-architect` | M | 0.1 | `npm run codegen` produces validators; all existing integration tests pass unchanged |
| **0.4** | Extract domain taxonomies into a single module | `backend/src/domain/taxonomies.js`; `models/User.js`, `validators/profile.validator.js`, `services/idealMatch.service.js` all import from it | `backend-engineer` | none | S | 0.1 (or independent) | grep finds zero duplicate enum arrays across `backend/src/` |
| **0.5** | Request-correlation IDs end-to-end | new `middleware/requestId.middleware.js`; pino child loggers in every service; propagate into socket emits and (future) job enqueues | `backend-engineer` | none | S | none | every log line has `req_id`; every Sentry event has `req_id`; spec'd how it flows into WS events |
| **0.6** | Introduce a realtime event-bus module | `backend/src/realtime/events.js`; refactor controllers + chat handler to call `events.emitNewMessage(io, payload)` etc | `backend-engineer` | none | M | 0.5 | grep finds zero `io.to(...).emit(...)` outside `src/realtime/`; integration tests unchanged |
| **0.7** | Introduce BullMQ job abstraction + standalone `worker` entrypoint | `backend/src/queue/`; new `backend/worker.js` entrypoint; `Dockerfile.worker`; sample noop job; ECS task / App Runner service skeleton handed to Deployment in 0.8 | `backend-engineer` | `deployment-pipeline-architect` | M | decision E | sample noop job enqueued via api, processed by worker; both run locally via `docker-compose up api worker` |
| **0.8** | CI/CD pipeline scaffold (AWS-targeted) | `.github/workflows/cd.yml`; push image to ECR on main; manual-approval deploy to staging on ECS/Fargate (or App Runner); Terraform skeleton for `vpc`, `ecr`, `ecs-cluster`, `secrets-manager` | `deployment-pipeline-architect` | `backend-engineer` | L | decisions C, E | push to main → image in ECR; `gh workflow run deploy-staging` deploys api + worker to ECS staging; rollback documented |
| **0.9** | Observability scaffold | `prom-client` in backend (api + worker) exposing `/metrics`; structured `auth.*`, `boost.*`, `match.*` event log names; CloudWatch log group convention; one Grafana board per service committed | `backend-engineer` | `deployment-pipeline-architect` | M | 0.5 | `curl /metrics` returns prometheus exposition for both services; Grafana board JSON committed |
| **0.10** | Monorepo tooling: npm workspaces + melos + remove vendored Flutter SDK | repo root (`package.json` workspaces), `melos.yaml`, `.fvmrc`, delete `flutter/` vendored SDK, update `.gitignore` and `README` | `general-purpose` | `frontend-ui-developer` | M | decision A | `flutter/` is gone from `main`; `.fvmrc` pins SDK version; `npm install` at root installs both `backend` and (any future) shared packages; clone size < 200MB |

### Phase 1 — Production-launch must-haves

| # | Title | Files / modules | Lead | Followers | Effort | Deps | Acceptance |
|---|---|---|---|---|---|---|---|
| **1.1** | Move Stripe boost activation into a job | `services/boost.service.handleStripeWebhook`; new `queue/jobs/boost.activate.js` | `backend-engineer` | none | S | 0.7 | webhook returns 200 in <50ms after signature check; activation processed async; integration test enqueues + asserts side-effect |
| **1.2** | Image-reaper job + pendingImageDeletes collection | new `models/PendingImageDelete.js`; `profile.service.deletePhoto`, `account.service.deleteAccount`; new `queue/jobs/media.delete.js` | `backend-engineer` | none | S | 0.7 | failed Cloudinary deletes show in the collection; reaper job drains them; metric `pending_image_delete_count` |
| **1.3** | Admin selfie-review queue + endpoints | `routes/admin.routes.js` add `GET /admin/selfies/pending` + `POST /admin/selfies/:userId/approve|reject`; service in `admin.service.js` | `backend-engineer` | `frontend-ui-developer` (admin UI later) | M | 0.1 | endpoint paginates pending; approve flips `isVerified=true` and `selfieReviewStatus=approved`; events logged |
| **1.4** | Idempotency middleware for mutation endpoints | `middleware/idempotency.middleware.js`; apply to `POST /messages`, `POST /swipe/like`, `POST /queue/accept/*` | `backend-engineer` | none | M | 0.5 | client retries with same `Idempotency-Key` return identical response; key persisted in Redis with 24h TTL |
| **1.5** | Mongo migration tool + first migration | `backend/migrations/`; CI runs migrations dry against a temp DB | `backend-engineer` | `deployment-pipeline-architect` | S | 0.8 | `npm run migrate` works; CI fails on unmigrated schema diffs |
| **1.6** | Production env-var schema + boot validation | `src/config/index.js` → Joi-validated; refuse to start in production without Stripe/Cloudinary/Firebase | `backend-engineer` | none | S | none | `NODE_ENV=production` with missing var crashes at boot, not on first request |
| **1.7** | Secrets out of repo | remove `backend/firebase-service-account.json`; document Secret Manager workflow | `deployment-pipeline-architect` | `backend-engineer` | S | none | repo grep for `private_key` returns nothing; rotation runbook exists |
| **1.8** | Frontend repositories for chat, matches, profile, boost, safety, account | new `features/*/data/*_repository.dart`; remove all `ref.read(dioProvider)` from widgets/notifiers | `frontend-ui-developer` | `design-architect` | L | 0.2 | grep finds zero `dio.get/post` outside `data/` |
| **1.9** | Single-flight refresh-token interceptor | `core/network/dio_client.dart` | `frontend-ui-developer` | none | S | none | concurrent 401s share one refresh future; widget test simulates 5 parallel 401s, exactly 1 refresh call |
| **1.10** | Auth bootstrap fetches /profile before redirect | `features/auth/presentation/providers/auth_provider.dart`; `core/router/app_router.dart` | `frontend-ui-developer` | none | S | 1.8 | returning user lands directly on /home from splash; widget test verifies no flicker through onboarding |
| **1.11** | Switch Flutter from dummy interceptor to real API + flavors verified | wherever dummy lives (per user, `lib/core/dummy/dummy_dio_interceptor.dart`); `.env.production` | `frontend-ui-developer` | none | S | 1.8, 0.10 | dev build hits localhost; staging build hits staging URL; prod build hits prod URL; smoke test passes against staging |
| **1.12** | Load test suite (k6) for REST + WS | `loadtest/` directory with scenarios | `test-suite-engineer` | `deployment-pipeline-architect` | M | 0.9 | k6 script runs 1k concurrent socket users, 100 msg/s, in CI nightly against staging; SLOs documented |
| **1.13** | Bring backend coverage back to 70% | fill gaps in `withTransaction`, refresh path, gender DB lookups | `test-suite-engineer` | `backend-engineer` | M | none | jest config back to `lines: 70`; CI green |
| **1.14** | Flutter widget + provider tests | `reverse_match/test/`; goldens for home/chat/matches; provider tests for auth/feed/matches | `test-suite-engineer` | `frontend-ui-developer` | M | 1.8 | `flutter test` reports ≥40% line coverage |
| **1.15** | Runbooks for top alerts | `docs/runbooks/*.md` — mongo-disk, redis-unreachable, stripe-webhook-failing, fcm-bounce | `deployment-pipeline-architect` | none | S | 0.9 | one MD per alert in repo; linked from Grafana panels |
| **1.16** | Production-grade infra | K8s/ECS manifests OR managed-PaaS config (Render/Fly/Railway); TLS termination; managed Atlas M10; managed Redis | `deployment-pipeline-architect` | none | XL | 0.8, Part 4 decisions B/C | `kubectl get pods` (or equivalent) shows api/worker/redis/mongo healthy; load balancer fronted by TLS; staging + prod environments isolated |
| **1.17** | GDPR-compatible delete + export | `account.service.deleteAccount` keeps audit log; new `GET /account/export` returns user ZIP | `backend-engineer` | none | M | none | export contains profile JSON + photo URLs; deletion writes a `DeletionRequest` row with timestamp + IP |

### Phase 2 — Scale to first 10k users

| # | Title | Files / modules | Lead | Followers | Effort | Deps | Acceptance |
|---|---|---|---|---|---|---|---|
| **2.1** | TTL skipped likes; consider Bloom filter for exclude set | `models/Like.js`, `swipe.service.getFeed` | `backend-engineer` | none | S | none | TTL index drops 30-day-old skipped rows; metric on collection size |
| **2.2** | Precompute ideal-match feature vectors nightly | `queue/jobs/idealmatch.precompute.js`; store on `User.featureVector` | `backend-engineer` | none | M | 0.7 | ideal-match request reduces to dot-product over N candidates; p95 latency drops by ≥50% |
| **2.3** | Denormalize lastMessage + unreadCount onto Match | `models/Match.js`, `services/message.service.sendMessage`, `services/message.service.markSeen`, `services/match.service.getMatches` | `backend-engineer` | none | M | 1.5 | getMatches aggregation removes 2 of 3 lookups; load test shows reduced Mongo CPU |
| **2.4** | Replace daysWithoutMatch counter with derived lastMatchedAt | `models/User.js`, `services/swipe.service`, `jobs/dailyBoost.job.js` (delete daily increment) | `backend-engineer` | none | M | 1.5 | daily-boost cron removed; auto-boost still computed correctly; backfill migration succeeds |
| **2.5** | Reconnect-replay backlog over Socket.IO | `socket/chat.handler.js`, `core/socket/socket_service.dart` | `backend-engineer` | `frontend-ui-developer` | M | 0.6 | client disconnects 30s, reconnects, receives missed messages; widget test verifies |
| **2.6** | De-duplicate socket fan-out (room-only OR personal-only) | `socket/chat.handler.js`, `controllers/message.controller.js` | `backend-engineer` | `frontend-ui-developer` | S | 0.6 | only one `new-message` event per recipient; frontend updated |
| **2.7** | Feature flag service | `src/featureFlags.js`; `/config` exposes flags to client | `backend-engineer` | `frontend-ui-developer` | M | none | flag toggled in Mongo flips behavior within 60s; metric exposes current values |
| **2.8** | Socket connect-rate limiter | `socket/index.js` handshake middleware | `backend-engineer` | none | S | 1.6 | bot can't open >N connect-attempts per IP per minute |
| **2.9** | CAPTCHA on first OTP send + Google sign-up | `routes/auth.routes.js`, frontend onboarding | `backend-engineer` | `frontend-ui-developer` | M | none | hCaptcha / reCAPTCHA challenge before OTP; verified server-side |
| **2.10** | Contract tests (Pact or shared fixtures) | `__tests__/contracts/`, `reverse_match/test/contracts/` | `test-suite-engineer` | `backend-engineer`, `frontend-ui-developer` | M | 0.1, 0.2 | each model fixture is validated by both server schema and Flutter parser in CI |

### Phase 3 — Long-term maintainability

| # | Title | Files / modules | Lead | Followers | Effort | Deps | Acceptance |
|---|---|---|---|---|---|---|---|
| **3.1** | Split worker into its own service / image | `worker.js` entrypoint; `Dockerfile.worker`; K8s deployment | `deployment-pipeline-architect` | `backend-engineer` | M | 0.7, 1.16 | api/worker scale independently; cron locks moot |
| **3.2** | Domain-driven module split | reorganize `services/` into `domain/{auth,profile,swipe,match,chat,boost,safety,account}` with explicit ports | `backend-engineer` | `design-architect` | XL | 0.4 | each domain has its own README, types, repository, service; cross-domain imports are explicit and few |
| **3.3** | ADR directory | `docs/adr/*.md` — Mongo vs Postgres, Riverpod vs BLoC, OpenAPI vs gRPC, monorepo decision, scoring offline vs on-request | `design-architect` | none | S–M | Part 4 decisions | every load-bearing decision has an ADR with date and signers |
| **3.4** | Move scoring to a dedicated service | a Python or Node worker reading from a vector index | `design-architect` (leads spec) → `backend-engineer` (executes) | none | XL | 2.2, Part 4 decision D | scoring service deployable independently; latency budget documented |
| **3.5** | Multi-region readiness audit | DB replication strategy, WS sticky sessions, FCM topic strategy | `design-architect` | `deployment-pipeline-architect` | L | 1.16 | ADR + diagram; not necessarily deployed |
| **3.6** | Frontend domain layer | introduce per-feature service objects between presentation and data; remove direct repository access from notifiers where it leaks domain rules | `frontend-ui-developer` | none | L | 1.8 | every notifier depends on a service, not a repository |
| **3.7** | Replace Mongoose with explicit repositories | `domain/*/repository.js` wrapping Mongo collection access | `backend-engineer` | none | XL | 3.2 | unit tests of services no longer touch Mongoose; in-memory fake repository swappable |
| **3.8** | Pre-commit hooks + Dependabot | husky + lint-staged; `.github/dependabot.yml` | `deployment-pipeline-architect` | none | S | none | every commit auto-formatted; weekly dependency PRs |

---

## Part 4 — Decisions (locked in 2026-05-14)

| # | Decision | Choice | Rationale |
|---|---|---|---|
| A | Repo layout | **Embrace monorepo** | Atomic contract changes are one PR; unblocks OpenAPI codegen feeding both sides. Adds tooling (npm workspaces + melos + remove vendored Flutter SDK + `.fvmrc`). |
| B | Mongo hosting | **MongoDB Atlas** (M10 for prod, M0/M2 for staging) | Solves transactions out of the box (`MONGO_TRANSACTIONS_ENABLED` flag can be removed), gives PITR + encryption + Vector Search if we want it later. |
| C | Cloud target | **AWS single-cloud** | Atlas runs natively on AWS for lowest cross-cloud latency. Use ECS/Fargate (or App Runner) for api + worker, ElastiCache for Redis, SES for email, ECR for images, Secrets Manager for secrets. Multi-cloud delays launch with no business reason today. |
| D | Ideal-match scoring | **On-request now; move offline in Phase 2** | Current implementation + 24h cache scales to ≤100k users. Don't pre-optimize. Trigger to move offline: DAU > 10k or p95 latency degradation. |
| E | Worker service | **Separate `worker` from day 1** | `api` and `worker` as two deploy units sharing the same monorepo code. Cron survives api crashes, no PM2 leader-election games, scaling axes independent. |
| F | Feature flags | **Build-time now; run-time in Phase 2** | dart-define + env vars for launch. Add Unleash (self-hosted, free) before 10k users. |
| G | Admin tooling | **Admin endpoints + Retool** | Build the REST surface (selfie review, ban queue, report queue) in Phase 1. Wire Retool against it. Skip the third frontend codebase. |

### How these decisions reshape the plan

- **Phase 0** now hard-includes monorepo tooling (decision A) and the worker scaffold (decision E).
- **Phase 1** drops the standalone-Mongo fallback (decision B), targets AWS (decision C), and adds admin endpoints (decision G).
- **Phase 2** is where run-time flags (F) and offline scoring (D) land.

---

## Part 5 — Verdict

Assuming Phase 0 and Phase 1 are completed, the system shifts from "well-built monolith with a partial frontend" to "small distributed system with contract-as-code." The OpenAPI spec becomes the single artifact between two cleanly versioned codebases; the realtime layer routes through a typed event bus; idempotent mutations and a job queue protect Stripe and Cloudinary from the consequences of network jitter; deletes are durable, secrets are out of the repo, infra is reproducible, and contract drift is caught by CI rather than by users. The architecture at that point is ready for **public launch through ~50k DAU** with a single PM2 cluster + worker + Atlas M10 + managed Redis + Cloudinary CDN + observability stack. **The 6-month risk** sitting on the other side of launch is unchanged in shape from today: the ideal-match scoring will be the first thing that breaks at scale (4.3 → 2.2 → 3.4) and the moderation/abuse story (13.2, 13.3, 2.9) will be the first thing that goes viral on Twitter if it lags. Plan the worker split and the scoring extraction (3.1, 3.4) into Q3; everything else is incremental.

---

**Key file paths referenced (absolute):**

- `C:\Users\agraw\dating\backend\src\app.js`
- `C:\Users\agraw\dating\backend\server.js`
- `C:\Users\agraw\dating\backend\src\routes\index.js`
- `C:\Users\agraw\dating\backend\src\config\index.js`
- `C:\Users\agraw\dating\backend\src\controllers\swipe.controller.js`, `match.controller.js`, `message.controller.js`, `boost.controller.js`, `auth.controller.js`, `profile.controller.js`, `admin.controller.js`
- `C:\Users\agraw\dating\backend\src\services\swipe.service.js`, `match.service.js`, `message.service.js`, `boost.service.js`, `auth.service.js`, `profile.service.js`, `idealMatch.service.js`, `queue.service.js`, `safety.service.js`, `account.service.js`, `admin.service.js`, `notification.service.js`, `upload.service.js`
- `C:\Users\agraw\dating\backend\src\socket\index.js`, `chat.handler.js`
- `C:\Users\agraw\dating\backend\src\jobs\dailyBoost.job.js`
- `C:\Users\agraw\dating\backend\src\models\User.js`, `Match.js`, `Like.js`, `Message.js`
- `C:\Users\agraw\dating\backend\src\middleware\auth.middleware.js`, `error.middleware.js`, `rateLimiter.middleware.js`
- `C:\Users\agraw\dating\backend\src\utils\cache.js`, `withTransaction.js`, `token.js`
- `C:\Users\agraw\dating\backend\src\validators\profile.validator.js`
- `C:\Users\agraw\dating\backend\Dockerfile`, `ecosystem.config.js`, `jest.config.js`
- `C:\Users\agraw\dating\docker-compose.yml`
- `C:\Users\agraw\dating\.github\workflows\ci.yml`
- `C:\Users\agraw\dating\reverse_match\lib\main.dart`
- `C:\Users\agraw\dating\reverse_match\lib\core\router\app_router.dart`
- `C:\Users\agraw\dating\reverse_match\lib\core\network\dio_client.dart`
- `C:\Users\agraw\dating\reverse_match\lib\core\socket\socket_service.dart`
- `C:\Users\agraw\dating\reverse_match\lib\core\constants\api_endpoints.dart`
- `C:\Users\agraw\dating\reverse_match\lib\features\auth\data\auth_repository.dart`
- `C:\Users\agraw\dating\reverse_match\lib\features\auth\presentation\providers\auth_provider.dart`
- `C:\Users\agraw\dating\reverse_match\lib\features\home\data\swipe_repository.dart`, `queue_repository.dart`
- `C:\Users\agraw\dating\reverse_match\lib\features\chat\presentation\screens\chat_screen.dart`
- `C:\Users\agraw\dating\reverse_match\lib\features\match\presentation\screens\matches_screen.dart`
- `C:\Users\agraw\dating\reverse_match\lib\shared\models\user_model.dart`
- `C:\Users\agraw\dating\flutter\` (vendored SDK — should be ignored/removed)
- `C:\Users\agraw\Downloads\BACKEND_API.md` (spec — should be moved into repo as `docs/api/openapi.yaml`)

---

## Appendix — Monorepo execution log

Phase 0.10 (executed 2026-05-14) turned the repo into a real monorepo and stopped vendoring the Flutter SDK.

- **Added**: root `package.json` (npm workspaces with `backend`, `engines.node >= 22`, Prettier/Husky/lint-staged dev deps, `format`/`format:check`/`prepare`/`lint:openapi` scripts), `.prettierrc.json`, `.prettierignore`, `melos.yaml` (Dart workspace; `packages/api-client-dart` reserved for Phase 0.2), `.fvmrc` pinning Flutter `3.41.9` (matching the previously vendored SDK; Dart 3.11.5).
- **Removed**: the vendored `flutter/` directory (~2.3 GB) is untracked from git going forward — it was already in `.gitignore` so `git rm --cached` is a no-op, but local copies remain on disk so dev environments keep working until contributors switch to FVM.
- **Updated**: root `README.md` (Repo layout, Local setup, FVM instructions); `reverse_match/README.md` (FVM bootstrap); `.gitignore` (added `.fvm/`, `node_modules/`, `.husky/_`, `.lint-staged-cache/`).
- **Contributor impact**: install Node >= 22 and FVM, then `npm install` at the repo root (one-time) and `fvm install` to materialise the pinned Flutter SDK. Pre-commit formatting via Husky + lint-staged activates after the first `npm install`.
- **Not touched** (owned by parallel agents): `backend/src/`, `backend/package.json`, `docs/api/`, `.github/workflows/`, `infra/`.