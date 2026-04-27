# Backend Roadmap — Reverse Match

**Stack:** Node.js / Express 5 / MongoDB / Redis / Socket.IO  
**Root:** `backend/`  
**Agent scope:** Everything inside `backend/`. Do NOT touch `reverse_match/`.

---

## Cross-dependency gates (wait for these before starting tagged tasks)

| Tag | What you need first | Provided by |
|-----|---------------------|-------------|
| `[NEEDS-FIREBASE]` | `google-services.json` service account key set in `.env` as `FIREBASE_SERVICE_ACCOUNT_JSON` | Deployment agent — Firebase project setup |
| `[NEEDS-SMTP]` | `SMTP_HOST`, `SMTP_PORT`, `SMTP_USER`, `SMTP_PASS` env vars | Deployment agent — SendGrid/SMTP setup |
| `[NEEDS-ATLAS]` | Production `MONGO_URI` pointing to Atlas M10+ | Deployment agent — MongoDB Atlas setup |
| `[NEEDS-SENTRY]` | Real `SENTRY_DSN` value in `.env` | Deployment agent — Sentry project setup |

For all other tasks: start immediately, no external blockers.

---

## Phase 1 — Testing Foundation (P0, do first — CI is a no-op without this)

### 1.1 Add ESLint

**Files to create/modify:**
- Create `backend/.eslintrc.json`
- Create `backend/.eslintignore`
- Install dev dependencies

```bash
cd backend
npm install --save-dev eslint eslint-config-airbnb-base eslint-plugin-import
```

`.eslintrc.json`:
```json
{
  "extends": ["airbnb-base"],
  "env": { "node": true, "es2022": true, "jest": true },
  "parserOptions": { "ecmaVersion": 2022 },
  "rules": {
    "no-underscore-dangle": ["error", { "allow": ["_id"] }],
    "no-console": "warn",
    "import/no-extraneous-dependencies": ["error", { "devDependencies": ["**/__tests__/**"] }]
  }
}
```

`.eslintignore`:
```
node_modules/
coverage/
```

**Update `package.json` scripts:**
```json
"lint": "eslint src/ --ext .js",
"lint:fix": "eslint src/ --ext .js --fix",
"test": "jest --coverage",
"test:unit": "jest --testPathPattern=unit",
"test:integration": "jest --testPathPattern=integration"
```

---

### 1.2 Add Jest + Supertest

```bash
cd backend
npm install --save-dev jest supertest @types/jest
```

Add to `package.json`:
```json
"jest": {
  "testEnvironment": "node",
  "coverageThreshold": { "global": { "lines": 70 } },
  "testPathIgnorePatterns": ["/node_modules/"]
}
```

---

### 1.3 Unit tests — services

Create `backend/__tests__/unit/services/` directory.  
Test each service with mocked DB (use `jest.mock`).

**`auth.service.test.js`** — test:
- `sendOtp`: generates OTP, hashes it, saves to DB, calls mailer
- `verifyOtp`: rejects expired OTP, rejects wrong OTP, returns tokens on success
- `refreshToken`: rejects tampered token, rotates correctly
- `googleLogin`: creates new user on first login, returns existing user on repeat

**`swipe.service.test.js`** — test:
- `getSwipeFeed`: respects geo filter, excludes already-seen users, excludes blocked users
- `swipeRight`: creates Like record, sends push notification to matched boy
- `swipeLeft`: records pass, does not create Like

**`boost.service.test.js`** — test:
- `activateBoost`: sets boostExpiresAt, updates boostRank
- Stripe webhook handler: idempotency key prevents duplicate activation

**`match.service.test.js`** — test:
- `getMatches`: returns only active matches for requesting user
- `unmatch`: deletes match, sends socket event to other user

**`safety.service.test.js`** — test:
- `blockUser`: creates Block record, removes any existing match/messages
- `reportUser`: creates Report record, does not duplicate

**`message.service.test.js`** — test:
- `sendMessage`: creates Message, updates match's `lastMessage`
- `markSeen`: updates seen status in DB (not just in-memory)

**`cache.test.js`** (`__tests__/unit/utils/`) — test:
- `setCache` / `getCache`: mock ioredis, verify TTL is set
- `invalidateCache`: verify del is called with correct key pattern

---

### 1.4 Integration tests — routes

Create `backend/__tests__/integration/` directory.  
Use Supertest + a real in-memory MongoDB (use `mongodb-memory-server`).

```bash
npm install --save-dev mongodb-memory-server
```

**`auth.routes.test.js`** — test all routes in `auth.routes.js`:
- `POST /api/v1/auth/send-otp` — happy path, missing phone, rate limit (mock Redis)
- `POST /api/v1/auth/verify-otp` — correct OTP returns tokens, wrong OTP returns 400
- `POST /api/v1/auth/refresh` — valid refresh token works, expired token returns 401
- `POST /api/v1/auth/google` — mock google-auth-library `verifyIdToken`
- `POST /api/v1/auth/logout` — clears refresh token from DB

**`profile.routes.test.js`**:
- `GET /api/v1/profile/me` — returns current user profile
- `PATCH /api/v1/profile` — updates allowed fields, rejects invalid data
- `POST /api/v1/profile/photos` — mocks Cloudinary upload, verifies photo count limit

**`swipe.routes.test.js`**:
- `GET /api/v1/swipe/feed` — female-only route, returns paginated results
- `POST /api/v1/swipe/:id/right` — creates Like, returns 404 for non-existent user
- `POST /api/v1/swipe/:id/left` — records pass

**`match.routes.test.js`**:
- `GET /api/v1/matches` — returns matches with cursor pagination
- `DELETE /api/v1/matches/:id` — unmatch

**`message.routes.test.js`**:
- `GET /api/v1/messages/:matchId` — returns messages with cursor pagination
- `POST /api/v1/messages/:matchId` — sends message

**`account.routes.test.js`**:
- `DELETE /api/v1/account` — verify cascade: deletes photos from Cloudinary, deletes Likes/Matches/Messages/Blocks/Reports, deletes User document

**`boost.routes.test.js`**:
- `POST /api/v1/boost/webhook` — mock Stripe event, verify idempotency

---

### 1.5 Socket.IO tests

Create `backend/__tests__/integration/socket.test.js`.

```bash
npm install --save-dev socket.io-client
```

Test:
- Client connects with valid JWT → authorized
- Client connects with invalid JWT → disconnected with error
- `sendMessage` event → other user in room receives `newMessage`
- `typing` event → other user receives `userTyping`
- `messageSeen` event → other user receives `messageSeenUpdate`; seen status persisted in DB

---

## Phase 2 — Security Hardening (P0)

### 2.1 Verify refresh token concurrent edge case

**File:** `src/services/auth.service.js`

Current implementation stores a hash of the refresh token on the User document. Verify:
1. When `refreshToken` is called, the old token hash is **immediately invalidated** before the new one is stored (no window where both are valid).
2. If two requests arrive simultaneously with the same refresh token, only one succeeds — the second should return 401 (token already consumed).

If the current implementation doesn't do atomic swap, implement it using a MongoDB findOneAndUpdate with `{ refreshTokenHash: oldHash }` as the filter condition so only one request wins.

---

### 2.2 Token blacklist on logout

**File:** `src/services/auth.service.js`, `src/config/redis.js`

On `POST /api/v1/auth/logout`:
1. Add the current access token's `jti` (JWT ID) to a Redis SET with TTL = remaining token lifetime.
2. In `auth.middleware.js`, after verifying the JWT signature, check Redis: if `jti` exists in blacklist → return 401.

If current JWT tokens don't include `jti`, add it in `src/utils/token.js` when signing tokens.

---

### 2.3 Age verification (18+) on signup

**Files:** `src/validators/auth.validator.js`, `src/services/auth.service.js`, `src/models/User.js`

1. Add `dateOfBirth` field to User model (type: Date, required: true for new users).
2. In OTP verify / Google login flow, if this is a new user being created, require `dateOfBirth` in the request body.
3. In the validator, verify the user is at least 18 years old: `new Date() - dob >= 18 * 365.25 * 24 * 60 * 60 * 1000`.
4. Return HTTP 400 with `{ message: 'You must be 18 or older to use Reverse Match' }` if underage.
5. The onboarding flow in Flutter sends `dateOfBirth` — verify the API endpoint that receives it validates age.

**Note:** Coordinate with Flutter agent — the `dob_screen.dart` in onboarding collects this value and must send it to the backend.

---

### 2.4 Input validation audit

**File:** Each file in `src/validators/`, each route in `src/routes/`

Audit every route to confirm a Joi validator is applied via `validate.middleware.js`. Specifically check:
- `account.routes.js` — account deletion route
- `safety.routes.js` — block and report routes  
- `queue.routes.js` — accept/reject actions

Add missing validators. All validators should use `.options({ stripUnknown: true })` to reject unknown fields.

---

### 2.5 OTP rate limiting verification

**File:** `src/middleware/rateLimiter.middleware.js`

Confirm that `POST /api/v1/auth/send-otp` has a **per-phone-number** rate limiter (not just per-IP), limiting to max 3 OTP requests per phone number per 10 minutes. If missing, add it using the existing Redis-based rate limiter pattern.

---

### 2.6 FCM device token management

**Files:** `src/models/User.js`, `src/services/auth.service.js`, `src/services/notification.service.js`

Current state: likely stores a single `fcmToken` on User.
Required:
1. Change `fcmToken` to `fcmTokens: [{ token: String, deviceId: String, addedAt: Date }]` to support multiple devices.
2. On login/refresh, upsert the token for the deviceId in the request (send `deviceId` header from Flutter).
3. On logout, remove only the token for the current deviceId.
4. On password change (if implemented), revoke ALL fcmTokens.
5. In `notification.service.js`, send to all tokens for a user; handle `registration-token-not-registered` errors by pruning stale tokens.

---

## Phase 3 — Feature Completeness (P0/P1)

### 3.1 Account deletion cascade cleanup

**File:** `src/services/account.service.js`

Verify (and fix if needed) that `deleteAccount` does ALL of:
1. Delete all photos from Cloudinary using stored `public_id` values.
2. Delete all `Like` documents where `fromUser` or `toUser` = userId.
3. Delete all `Match` documents where `user1` or `user2` = userId.
4. Delete all `Message` documents in matches involving userId.
5. Delete all `Block` documents involving userId.
6. Delete all `Report` documents filed by userId (reports filed AGAINST the user can be kept for audit).
7. Revoke all FCM tokens (clear `fcmTokens` array before user deletion).
8. Delete the User document last.

Use a MongoDB session/transaction for atomicity where possible.

---

### 3.2 Message delivery receipts persistence

**File:** `src/models/Message.js`, `src/socket/chat.handler.js`

Check whether `seen: true` is persisted to MongoDB when the `messageSeen` socket event fires, or if it only lives in memory.

If in-memory only: in `chat.handler.js`, when handling `messageSeen`, call `Message.findByIdAndUpdate(messageId, { seen: true, seenAt: new Date() })`.

Also verify `GET /api/v1/messages/:matchId` returns the `seen` field in the response.

---

### 3.3 Pagination verification

**File:** `src/services/match.service.js`, `src/services/message.service.js`

Verify both endpoints use **cursor-based** (not offset-based) pagination:
- `GET /api/v1/matches?cursor=<lastMatchId>&limit=20` — filter `{ _id: { $lt: cursor } }`, sort `{ _id: -1 }`, limit 20.
- `GET /api/v1/messages/:matchId?cursor=<lastMessageId>&limit=30` — same pattern.

If using offset pagination, convert to cursor pagination. Offset pagination breaks on large datasets when new records are inserted between page fetches.

---

### 3.4 Profile photo max count enforcement

**File:** `src/services/profile.service.js` or `src/services/upload.service.js`

Before uploading a new photo, count existing photos for the user. If count ≥ max allowed (check `app_constants.dart` in Flutter for the value, likely 6), return HTTP 400 `{ message: 'Maximum photos reached' }`. Do not upload to Cloudinary before checking.

---

### 3.5 Admin moderation API (P1)

Create `src/routes/admin.routes.js` (protected by a new `isAdmin` middleware that checks `user.role === 'admin'`).

Endpoints needed:
- `GET /api/v1/admin/reports?status=pending&page=1` — list reports with user details populated
- `POST /api/v1/admin/reports/:id/resolve` — mark report resolved, optionally ban user
- `POST /api/v1/admin/users/:id/ban` — set `user.banned = true`, revoke all tokens, send notification
- `GET /api/v1/admin/users/:id` — view full user profile for review

Add `banned: Boolean` and `role: { type: String, enum: ['user', 'admin'], default: 'user' }` to `User.js` model.

In `auth.middleware.js`, check `user.banned` — if true, return 403 `{ message: 'Your account has been suspended' }`.

---

### 3.6 MongoDB indexes audit (P1)

**File:** `src/models/*.js`

Add these indexes if not present:

```js
// User.js
UserSchema.index({ location: '2dsphere' });
UserSchema.index({ gender: 1, 'location.coordinates': '2dsphere' });
UserSchema.index({ phone: 1 }, { unique: true });

// Like.js
LikeSchema.index({ fromUser: 1, status: 1 });
LikeSchema.index({ toUser: 1, status: 1 });
LikeSchema.index({ fromUser: 1, toUser: 1 }, { unique: true });

// Match.js
MatchSchema.index({ user1: 1 });
MatchSchema.index({ user2: 1 });

// Message.js
MessageSchema.index({ matchId: 1, createdAt: -1 });

// Report.js
ReportSchema.index({ reportedUser: 1, status: 1 });
```

After adding, run `db.collection.explain("executionStats")` on the most frequent queries (swipe feed, message list) to verify indexes are being used.

---

### 3.7 HTML email templates (P2) `[NEEDS-SMTP]`

**File:** `src/utils/otp.js` or wherever `nodemailer` is called

Replace plain-text OTP email with an HTML template:
```html
<div style="font-family: sans-serif; max-width: 400px; margin: 0 auto;">
  <h2 style="color: #E91E8C;">Reverse Match</h2>
  <p>Your verification code is:</p>
  <h1 style="letter-spacing: 8px; color: #333;">{{OTP}}</h1>
  <p style="color: #888; font-size: 12px;">Expires in 10 minutes. Do not share this code.</p>
</div>
```

---

## Phase 4 — Google OAuth verification

**File:** `src/config/firebase.js` or wherever `google-auth-library` is used  `[NEEDS-FIREBASE]`

Confirm `googleLogin` service does:
```js
const ticket = await client.verifyIdToken({
  idToken: googleToken,
  audience: process.env.GOOGLE_CLIENT_ID, // must match Flutter OAuth client ID
});
```

The `audience` check is critical — without it, tokens from other Google apps are accepted.

---

## Deliverables checklist

- [ ] ESLint config added, `npm run lint` exits 0
- [ ] Jest + Supertest installed, `npm test` runs and produces coverage report
- [ ] Unit tests for all 7 services (auth, swipe, boost, match, safety, message, cache)
- [ ] Integration tests for all 9 route files
- [ ] Socket.IO tests covering connect/auth/message/typing/seen
- [ ] Concurrent refresh token edge case handled atomically
- [ ] JWT blacklist on logout implemented via Redis
- [ ] Age 18+ verification on signup (backend rejects underage)
- [ ] OTP rate limit is per-phone-number (not just per-IP)
- [ ] FCM supports multiple device tokens
- [ ] Account deletion deletes Cloudinary photos + all related DB documents
- [ ] `seen` status persisted to MongoDB (not in-memory only)
- [ ] Cursor pagination on `/matches` and `/messages/:matchId`
- [ ] Photo upload blocked at max count before hitting Cloudinary
- [ ] Admin API: list reports, ban users, resolve reports
- [ ] `User.banned` check in auth middleware
- [ ] MongoDB indexes added for geo, Like, Match, Message, Report
- [ ] `npm run lint` and `npm test` both produce real output (not echo)
