# Deploying Reverse Match to Zoho Catalyst AppSail

This runbook deploys the backend to **Zoho Catalyst AppSail** as three custom
(Docker) runtime services: **api**, **worker**, and **ml**. It assumes MongoDB
Atlas, a cloud Redis (TLS), and all third-party credentials are already
provisioned.

> Why custom Docker runtime: AppSail's managed Node runtime tops out around
> Node 18/20; the backend targets Node 22. Custom runtime runs our existing
> Dockerfiles unchanged (aside from the port handling already wired in).

## AppSail model — what shaped this setup

- Apps bind the port in **`X_ZOHO_CATALYST_LISTEN_PORT`** (default 9000), not a
  fixed `PORT`. The code maps it automatically (`backend/src/config/index.js`,
  `backend/worker.js`, `ml-service/Dockerfile`).
- Instances live ~**5 min**, max **5 per app**, **100 concurrent req/instance**,
  hard **30 s request timeout**.
- Secrets are **env vars**, not files → Firebase is provided as inline JSON
  (`FIREBASE_SERVICE_ACCOUNT_JSON`).
- Scheduled work can't rely on an always-on process → **Catalyst Cron** drives it.

---

## 0. Prerequisites

- Docker Desktop running (builds Linux **amd64** images).
- Node 18+ for the Catalyst CLI.
- A Zoho account for Catalyst (e.g. `omswork26@gmail.com`).
- Connection strings + creds: Atlas `MONGO_URI`, cloud Redis `REDIS_URL` (TLS,
  e.g. `rediss://...`), JWT secrets, `OTP_PEPPER`, Stripe (live), Cloudinary,
  Firebase service-account JSON, Google OAuth client id, SMTP.

Generate the secrets that are ours to make:
```bash
# 32-byte hex secrets
openssl rand -hex 32   # JWT_ACCESS_SECRET
openssl rand -hex 32   # JWT_REFRESH_SECRET
openssl rand -hex 32   # OTP_PEPPER
openssl rand -hex 32   # CRON_SECRET        (guards /internal/cron/*)
openssl rand -hex 32   # ML_SERVICE_API_KEY (shared api <-> ml)
```

Validate the env locally before building (point a shell at the prod values):
```bash
cd backend && NODE_ENV=production npm run check:env   # expect "ok": true
```

---

## 1. Install CLI, log in, create the project

```bash
npm install -g zcatalyst-cli
catalyst login          # interactive browser auth — run via `! catalyst login`
```
Create a **project** in the Catalyst console (https://catalyst.zoho.com), note its
**project name / id** and **data center**.

---

## 2. Build the three images (amd64)

From the repo root (`C:\Users\agraw\dating`):
```powershell
docker build --platform linux/amd64 -t reverse-match-api:latest    -f backend/Dockerfile        backend
docker build --platform linux/amd64 -t reverse-match-worker:latest -f backend/Dockerfile.worker backend
docker build --platform linux/amd64 -t reverse-match-ml:latest     -f ml-service/Dockerfile     ml-service
```
> The ML image is large (torch + sentence-transformers). First build is slow.
> Optional: bake the embedding model into the image so it isn't downloaded on
> every cold start.

---

## 3. Add the AppSail services

`catalyst init` at the repo root, then add each service as a **custom (Docker)
runtime**. Run once per service and follow the prompts (runtime type → *Docker
Image*; protocol → *Docker Image*; pick the local image; name the service):
```bash
catalyst init
catalyst appsail:add     # -> reverse-match-api,    image reverse-match-api:latest,    port 9000
catalyst appsail:add     # -> reverse-match-worker, image reverse-match-worker:latest, port 9000
catalyst appsail:add     # -> reverse-match-ml,     image reverse-match-ml:latest,     port 9000
```
This writes `catalyst.json`. Bump the **ml** service memory well above the
512 MB default (≥1–2 GB) in the console Configuration tab or `catalyst.json`.

> Alternative (no init): standalone deploy per service, e.g.
> `catalyst deploy appsail --name reverse-match-api --source docker://localhost/reverse-match-api:latest --port 9000`

---

## 4. Set environment variables (per service)

Set these in the console **AppSail → service → Configuration → Environment
Variables** (preferred — keeps secrets out of `catalyst.json`). Source of truth
for descriptions: `backend/.env.example`.

### api (`reverse-match-api`)
| Var | Value |
|---|---|
| `NODE_ENV` | `production` |
| `MONGO_URI` | Atlas SRV URI (`...?retryWrites=true&w=majority`) |
| `REDIS_URL` | cloud Redis TLS URL (`rediss://...`) |
| `JWT_ACCESS_SECRET` / `JWT_REFRESH_SECRET` | hex secrets |
| `OTP_PEPPER` | hex secret |
| `CLOUDINARY_CLOUD_NAME` / `CLOUDINARY_API_KEY` / `CLOUDINARY_API_SECRET` | Cloudinary |
| `STRIPE_SECRET_KEY` / `STRIPE_WEBHOOK_SECRET` | Stripe (live) |
| `GOOGLE_CLIENT_ID` | Google OAuth web client id |
| `SMTP_HOST` / `SMTP_PORT` / `SMTP_USER` / `SMTP_PASS` | email transport |
| `FIREBASE_SERVICE_ACCOUNT_JSON` | full service-account JSON (single line) |
| `CRON_SECRET` | hex secret (matches Catalyst Cron headers) |
| `CORS_ORIGINS` | comma-separated app/web origins |
| `APP_BASE_URL` | the api's public AppSail URL (set after step 5) |
| `ML_SERVICE_URL` | the ml service's URL (set after step 5) |
| `ML_SERVICE_API_KEY` | hex secret (matches ml) |
| `SENTRY_DSN` | optional |
| `BULLMQ_QUEUE_PREFIX` | e.g. `rm` |

### worker (`reverse-match-worker`)
Same as api **minus** the api-only entries (`CORS_ORIGINS`, `APP_BASE_URL`,
`ML_SERVICE_URL`). It needs DB/Redis/Cloudinary/Stripe/Firebase + `NODE_ENV`,
`BULLMQ_QUEUE_PREFIX`, and the JWT/OTP secrets.

### ml (`reverse-match-ml`)
From `ml-service/.env.example`: `MONGO_URI` (same Atlas DB),
`ML_SERVICE_API_KEY` (matches api), `EMBED_MODEL`, `TEXT_EMBED_DIM`,
`CANDIDATES_K`, `TOP_K`, `FAISS_NLIST`, `IDEAL_MATCH_MIN_*`, `EXPLORE_*`,
`TIME_DECAY_HALF_LIFE`, `AUTO_REBUILD_ON_BOOT`, `REBUILD_MIN_USERS`, `LOG_LEVEL`.

---

## 5. Deploy and capture URLs

```bash
catalyst deploy            # or: catalyst deploy appsail
```
The CLI prints each service's endpoint URL. Then:
- Set api `APP_BASE_URL` = api URL, `ML_SERVICE_URL` = ml URL, `CORS_ORIGINS` =
  real origins, and redeploy/restart the api.

---

## 6. Run migrations (Atlas)

```bash
cd backend
# with MONGO_URI pointed at Atlas:
npm run migrate
npm run migrate:status     # all "up"
```

---

## 7. Stripe webhook

In the Stripe dashboard add a webhook endpoint:
```
https://<api-endpoint>/api/v1/boost/webhook
```
Copy its signing secret into the api's `STRIPE_WEBHOOK_SECRET`.

---

## 8. Catalyst Cron (replaces the in-process node-cron)

In production the api does **not** run node-cron (gated in `server.js`); create
these schedules in **Catalyst → Cloud Scale → Cron** (or Job Scheduling). Each
sends header `X-Cron-Secret: <CRON_SECRET>`.

| Schedule | Target | Purpose |
|---|---|---|
| every ~1 min | `GET https://<worker>/health` | keep a worker instance warm so BullMQ drains |
| daily `0 0 * * *` (UTC) | `POST https://<api>/internal/cron/daily-boost` | increment `daysWithoutMatch` |
| hourly `0 * * * *` | `POST https://<api>/internal/cron/clear-expired-boosts` | clear expired boosts |

Manual check:
```bash
curl -X POST https://<api>/internal/cron/clear-expired-boosts -H "X-Cron-Secret: <CRON_SECRET>"
# -> {"ok":true,"job":"clear-expired-boosts","cleared":N}
```

---

## 9. Verify end-to-end

1. `GET https://<api>/health` → 200, `mongodb: connected`, `redis: connected`.
2. `GET https://<api>/ready` → ready; `GET https://<worker>/health` → ok;
   `GET https://<ml>/health` → ok.
3. `GET https://<api>/api/v1/config` → app config JSON.
4. OTP signup (SMTP) → profile → photo upload (Cloudinary).
5. Boost checkout → Stripe **test** payment → webhook enqueues `boost.activate`
   → worker applies it within ~1 min (keep-alive cron holds the worker warm).
6. Trigger both `/internal/cron/*` endpoints; confirm Mongo updates + logs.
7. **Real-time chat (risk item):** connect two Socket.IO clients, exchange
   messages, and watch for drops across the 30 s timeout / 5-min recycle.

---

## Known limitations / follow-ups

- **Socket.IO**: persistent WebSockets are the weakest fit for AppSail. If step 9.7
  shows drops, host realtime on a persistent host (VM/Render/Fly) and keep only
  the REST api on AppSail.
- **Worker**: kept warm by a Cron ping — pragmatic, not ideal. Jobs may wait up
  to ~1 min between warm windows; `boost.activate` retries cover it.
- **ML**: heaviest service; FAISS index is in-memory and rebuilds on cold start.
  Bump memory and bake the model in; add persistence later.
- Existing AWS Terraform/CD under `infra/` is left untouched (not the chosen
  target).
- Pre-existing repo lint errors in `backend/src/services/mlMatch.client.js`
  (5 formatting issues) are unrelated to this deployment; `npm run lint --fix`
  clears them if you want CI green.
