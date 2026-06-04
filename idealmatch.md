# Ideal Match — Feature & ML Setup Guide

> **Purpose:** Self-contained runbook. Next time, say *"read `idealmatch.md` and get the ML running"* and everything below can be followed end-to-end. Covers what the feature is, how the ML model works, every file involved, and exact copy-paste commands to run the ML service and wire it to the backend.

---

## 1. What the feature is

**Ideal Match** is a **girls-only** feature. A girl opens the Ideal Match screen and taps **"Find My Ideal"** → the matchmaker returns **the single most compatible profile** for her.

**Three gates (all must pass; enforced server-side from durable Mongo data):**
1. **≥ 10 swipes** — counted from `Like` docs (`fromUser = her`, like+skip both).
2. **≥ 80% profile completion** — 11 key fields (name, age, gender, ≥2 photos, bio, prompts, interests, education, hometown/city, datingIntentions, height).
3. **Weekly cap = 2** — rolling 7-day window, stored as `User.idealMatchUses: [Date]`.

A weekly use is **only consumed when a match is successfully produced** (a "no candidates" result never wastes a try).

---

## 2. How the ML model finds the ideal match

Pipeline (Python service in `ml-service/`):

1. **Personality embedding (text → vector):** for every user, `build_bio_text` concatenates name + bio + interests + prompts + jobTitle + religion + politics + education + hometown + dating intent. **SentenceTransformer** (`all-MiniLM-L6-v2`) encodes it into a **384-dim L2-normalized vector** (so dot-product = cosine similarity).
2. **FAISS index** (IVFFlat, inner-product) over all user vectors → fast approximate nearest-neighbor retrieval of top-K candidates.
3. **Dynamic per-user vector (learns from swipes):** each user has a `DynamicUserEmbedding` = `long_term` (EMA of liked profiles) + `session` (last 20 swipes), fused `0.7*long_term + 0.3*session`. Event weights: `right_swipe +1`, `match +2`, `message +1.5`, `reply +2`, `left_swipe -0.5`, `unmatch -1`. **Time-decay** half-life ~7 days. → The more she swipes, the better it learns her *actual* taste (not just what she wrote).
4. **`ideal_match_unlocked`** flag in ML unlocks at `total_swipes ≥ 20` OR `right_swipes ≥ 10` (config defaults).
5. **Pick THE one (`PerfectMatchEngine.select_daily_match`):** filter candidates (opposite gender = boys, not seen/blocked/matched/liked/self), compute cosine similarity, **take the single highest = ideal match** (pure argmax, no exploration randomness).
6. **Explainability:** "Why you two click" reasons (semantic score, shared interests, same city, same intent, same religion).

> **NOT per-user training.** There is ONE shared pretrained embedder + ONE shared FAISS index. The per-user part is a lightweight evolving vector updated by a simple EMA formula — no gradient descent / no model training per person.

**Where data lives:**
- Profiles + swipes (`Like` docs) → **MongoDB (durable)**.
- The per-user dynamic vectors + swipe counters → **Python process RAM only (NOT persisted)**. On ML restart they reset and are re-seeded from profile text via `rebuild_from_mongo` (swipe history is *not* replayed — MVP gap). This is why the **swipe gate is enforced in Node from Mongo**, not from the ML's RAM counter.

---

## 3. Two engines (automatic)

- **Primary: Python ML service** (FAISS + SentenceTransformer) — used when `ML_SERVICE_URL` is set in `backend/.env`.
- **Fallback: Node cosine** (`idealMatch.service.js`) — one-hot + cosine over taxonomies. Runs automatically when ML is **disabled, down, or returns nothing**. The feature works fully on the fallback; ML just adds personality-embedding + swipe-learning quality.

Node calls ML via `POST /v1/recommend` (k=1) — ungated; the Node gates decide eligibility. (`/v1/daily-match` is the gated pure-top-1 alternative; we use `recommend` k=1 so an ML restart can't wrongly lock a girl.)

---

## 4. Files involved

### Backend (Node) — `backend/src/`
| File | Role |
|---|---|
| `routes/index.js` | `/ideal-match` mounted with `auth + requireGender('female')` |
| `routes/idealMatch.routes.js` | `GET /status`, `POST /reveal`, `GET /` |
| `controllers/idealMatch.controller.js` | `getStatus`, `reveal`, `getIdealMatch` |
| `services/idealMatch.service.js` | gates (`getIdealMatchStatus`), `revealIdealMatch`, `computeCompletion`, ML call + cosine fallback (`getIdealMatch`) |
| `services/mlMatch.client.js` | thin HTTP client to the Python service (`recommend`, `dailyMatch`, `recordEvent`, `rebuildIndex`) |
| `models/User.js` | `idealMatchUses: [Date]` field (weekly cap) |

**Endpoints:**
- `GET /api/v1/ideal-match/status` → `{ eligible, swipeCount, minSwipes, completion, completionThreshold, usesThisWeek, weeklyCap, nextResetAt, swipesOk, profileOk, capOk }` (no use spent)
- `POST /api/v1/ideal-match/reveal` → `{ topMatch, score, commonalities, usesThisWeek, weeklyCap }` (spends one use)

### Python ML — `ml-service/`
| File | Role |
|---|---|
| `app/main.py` | FastAPI: `/health`, `/v1/recommend`, `/v1/event`, `/v1/daily-match/{id}`, `/v1/weekly-matches/{id}`, `/v1/admin/rebuild` |
| `app/state.py` | live pipeline: build index, recommend, daily/weekly, record_event |
| `app/algorithm.py` | embedder, FAISS engine, dynamic embedding, bandit, PerfectMatchEngine, explainer |
| `app/adapter.py` | Mongo access, `build_bio_text`, gender/exclusion resolution |
| `app/config.py` | env-driven settings |
| `requirements.txt` | deps (**includes `dnspython` for Atlas srv**) |
| `Dockerfile` | python:3.11-slim, **CPU-only torch** install |

### Frontend (Flutter) — `reverse_match/lib/`
| File | Role |
|---|---|
| `features/ideal_match/data/ideal_match_repository.dart` | raw-Dio `getStatus()` + `reveal()`, `IdealMatchStatus` + `IdealMatchResult` models |
| `features/ideal_match/presentation/screens/ideal_match_screen.dart` | gate checklist, locked states, "Find My Ideal" + result card |
| `features/home/presentation/screens/girl_home_screen.dart` | ✨ button in the feed top bar → `/ideal-match` |
| `core/router/app_router.dart` | `/ideal-match` route |
| `core/constants/api_endpoints.dart` | `idealMatchStatus`, `idealMatchReveal` |

---

## 5. Prerequisites (READ FIRST)

- ⚠️ **Disk: at least ~10 GB free on C:.** The ML image (CPU torch + faiss + sentence-transformers) is ~3–4 GB. With low disk, Docker Desktop **crashes** ("unable to start") during image unpack. *(This was the blocker last time — C: had only 0.1 GB free.)*
  - Check: `Get-PSDrive C | Select-Object Free,Used`
- **Docker Desktop running.** Start it, then verify: `docker info --format '{{.ServerVersion}}'`
- **Backend `.env`** has the Atlas `MONGO_URI` (the ML service reads the same DB).

---

## 6. Already-applied fixes (don't redo)

These are committed in the repo so the build works against Atlas:
1. `ml-service/requirements.txt` → added **`dnspython==2.7.0`** (needed for `mongodb+srv://` Atlas URIs; without it pymongo throws "dnspython is not installed").
2. `ml-service/Dockerfile` → installs **CPU-only torch** first:
   ```
   pip install --index-url https://download.pytorch.org/whl/cpu torch==2.4.1
   ```
   (The default torch wheel pulls ~5 GB of CUDA libs we never use → fills disk → build fails.)

---

## 7. Run the ML service (copy-paste, Docker)

> Run from anywhere; paths are absolute. `MONGO_URI` value = copy the exact string from `backend/.env`.

```powershell
# 0. Ensure Docker is up (start Docker Desktop first if needed)
docker info --format '{{.ServerVersion}}'

# 1. (Optional) reclaim space
docker builder prune -f

# 2. Build the image (~3-5 min; CPU torch, no CUDA)
docker build -t reverse-match-ml "D:\dating\2nd\dating-main\dating-main\ml-service"

# 3. Run it — point at the SAME Atlas DB the backend uses.
#    Replace <MONGO_URI> with the value from backend/.env
docker run -d --name rm-ml -p 8000:8000 `
  -e MONGO_URI="<MONGO_URI from backend/.env>" `
  -e AUTO_REBUILD_ON_BOOT=true `
  -e REBUILD_MIN_USERS=1 `
  -e DATA_DIR=/app/data `
  reverse-match-ml

# 4. Wait for it to be ready (first boot downloads the ~80MB model, then
#    builds the FAISS index from Atlas users). Poll until ready:true:
#    (re-run a few times)
curl http://localhost:8000/health
```

`/health` should eventually return `{"status":"ok","ready":true,"indexed_users":N,...}`.

**Useful ML ops:**
```powershell
docker logs -f rm-ml                                  # watch boot/index logs
curl -X POST http://localhost:8000/v1/admin/rebuild   # rebuild index after new users sign up
docker stop rm-ml ; docker rm rm-ml                   # stop & remove
docker start rm-ml                                    # start again later
```

> If `ready:false` with `reason: below_min_users` → there aren't enough eligible users; lower `REBUILD_MIN_USERS` (already 1) or add/complete profiles, then hit `/v1/admin/rebuild`.

---

## 8. Wire the backend to the ML service

1. Edit `backend/.env` — set:
   ```
   ML_SERVICE_URL=http://localhost:8000
   # ML_SERVICE_API_KEY=         # leave blank (must match ml-service; blank = no auth)
   # ML_SERVICE_TIMEOUT_MS=2500  # optional
   ```
2. Restart the backend:
   ```powershell
   # stop whatever is on :5000, then:
   $env:NODE_ENV='development'; node "D:\dating\2nd\dating-main\dating-main\backend\server.js"
   ```
3. **Verify** it's using real ML: trigger an ideal-match reveal from the app (girl account, gates passed) — the response now comes from FAISS. In `idealMatch.service.js` the ML path tags results with `source: 'ml'`; the cosine fallback has no `source`. You can also watch `docker logs -f rm-ml` for `/v1/recommend` hits.

> If `ML_SERVICE_URL` is **blank** (default), the backend silently uses the **cosine fallback** — the feature still works, just without personality-embedding/swipe-learning.

---

## 9. Gotchas / design notes

- **Dynamic store is RAM-only** → ML restart forgets learned swipe-taste (re-seeds from profile text). The **10-swipe gate is enforced in Node from Mongo `Like` docs**, so a restart never wrongly locks/unlocks anyone.
- **`/recommend` (k=1, ungated)** is what Node calls — restart-immune. `/daily-match` is gated by the RAM `ideal_match_unlocked` (min 20 swipes), so we avoid it for the gate.
- **ML `IDEAL_MATCH_MIN_SWIPES=20`** is the ML's own unlock; our product gate is **10** and lives in Node — they're independent. (We don't rely on the ML unlock.)
- **Cosine fallback always backs up the ML** — the feature degrades gracefully, never errors out because ML is down.
- **CPU-only** by design (no GPU needed).

---

## 10. Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| Docker "unable to start" / build EOF at unpack | **C: disk full** | Free ~10 GB, restart Docker (`wsl --shutdown` + relaunch) |
| Build `OSError [Errno 5]` during install | torch pulling CUDA libs | Already fixed (CPU torch in Dockerfile) |
| ML logs: `dnspython is not installed` | Atlas srv URI without dnspython | Already fixed (`dnspython` in requirements) |
| `/health` `ready:false` | index not built / too few users | `curl -X POST /v1/admin/rebuild`; check `REBUILD_MIN_USERS` |
| Reveal still feels generic | `ML_SERVICE_URL` blank → cosine fallback | set `ML_SERVICE_URL` + restart backend |
| Backend reveal 403/429 | gate not met / weekly cap | swipe ≥10, profile ≥80%, ≤2 uses/week |

---

## 11. "Next time" quick checklist

```powershell
# 1. Free disk (need ~10 GB), start Docker Desktop, then:
docker info --format '{{.ServerVersion}}'

# 2. Build + run ML (MONGO_URI from backend/.env):
docker build -t reverse-match-ml "D:\dating\2nd\dating-main\dating-main\ml-service"
docker run -d --name rm-ml -p 8000:8000 -e MONGO_URI="<from backend/.env>" -e AUTO_REBUILD_ON_BOOT=true -e REBUILD_MIN_USERS=1 reverse-match-ml
curl http://localhost:8000/health        # wait for ready:true

# 3. backend/.env: set ML_SERVICE_URL=http://localhost:8000  → restart backend
# 4. Test reveal from the app (girl account, gates passed).
```

Then just tell me: **"idealmatch.md padho aur ML chalao"** and I'll execute this end-to-end.
