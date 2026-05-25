# Reverse Match — ML Service

Python FastAPI microservice that wraps the industrial matchmaking algorithm
(SentenceTransformer + FAISS + dynamic per-user embeddings + Thompson
Sampling bandit + Perfect Match engine) and exposes it to the Node.js
backend over HTTP.

## Where this lives in the architecture

```
┌─────────────┐    HTTP (json)    ┌──────────────────┐    PyMongo    ┌──────┐
│  Node API   │ ───────────────▶  │   ml-service     │ ────────────▶ │ Mongo│
│ (backend/)  │ ◀───────────────  │   (FastAPI)      │               └──────┘
└─────────────┘                   └──────────────────┘
       │
       └── fallback: legacy one-hot cosine in `idealMatch.service.js`
```

* The Node backend calls this service from `backend/src/services/mlMatch.client.js`.
* `idealMatch.service.js` tries the ML path first and falls back to the
  legacy cosine encoder if the ML service is unreachable or returns no
  candidates. Failures never bubble up to the user.
* Swipe / accept / reject events are mirrored to `POST /v1/event`
  (fire-and-forget) so the dynamic embeddings learn from real behavior.

## Endpoints

All endpoints (except `/health`) require the `x-api-key` header when
`ML_SERVICE_API_KEY` is set.

| Method | Path                              | Purpose                                                          |
|--------|-----------------------------------|------------------------------------------------------------------|
| GET    | `/health`                         | Liveness + index readiness                                       |
| POST   | `/v1/recommend`                   | Top-K personalised candidates for a user                         |
| POST   | `/v1/event`                       | Record a behavioral event (`right_swipe`, `match`, …)            |
| GET    | `/v1/daily-match/{user_id}`       | Daily top-1 elite match (after ideal-match is unlocked)          |
| GET    | `/v1/weekly-matches/{user_id}`    | Weekly safe + diverse + exploration matches                      |
| POST   | `/v1/admin/rebuild`               | Rebuild FAISS index from current Mongo `users` collection        |

### `POST /v1/recommend`

```json
{ "user_id": "65a1...", "k": 20 }
```

Returns:

```json
{
  "viewer_id": "65a1...",
  "recommendations": [
    {
      "candidate_id": "65a2...",
      "score": 0.831,
      "base_score": 0.802,
      "reasons": ["Strong personality match (0.83)", "Shared interests: …"],
      "profile": { "id": "65a2...", "name": "…", "age": 27, "gender": "male", … }
    }
  ],
  "ideal_match_unlocked": false,
  "total_swipes": 4,
  "right_swipes": 2
}
```

### `POST /v1/event`

```json
{
  "user_id": "65a1...",
  "target_id": "65a2...",
  "event_type": "right_swipe",
  "timestamp": 1719700000.5
}
```

Event types: `right_swipe`, `left_swipe`, `match`, `message`, `reply`,
`ghost`, `unmatch`.

## Environment

See `.env.example`. Key vars:

| Var                       | Default              | Notes                                              |
|---------------------------|----------------------|----------------------------------------------------|
| `MONGO_URI`               | localhost            | Same DB the Node backend uses                      |
| `ML_SERVICE_API_KEY`      | empty (auth off)     | Shared secret with the Node backend                |
| `EMBED_MODEL`             | `all-MiniLM-L6-v2`   | Any SentenceTransformer model                      |
| `TEXT_EMBED_DIM`          | 384                  | Must match the chosen model                        |
| `CANDIDATES_K`            | 100                  | FAISS overfetch size before re-ranking             |
| `IDEAL_MATCH_MIN_SWIPES`  | 20                   | Threshold to unlock daily/weekly matches           |
| `IDEAL_MATCH_MIN_RIGHT`   | 10                   | Alt threshold (whichever fires first)              |
| `EXPLORE_WEIGHT`          | 0.2                  | Bandit exploration mix (0=pure exploit, 1=random)  |
| `TIME_DECAY_HALF_LIFE`    | 7.0 days             | How fast old events fade from the embedding        |
| `AUTO_REBUILD_ON_BOOT`    | `true`               | Build index from Mongo when the service starts     |

## Local run (without Docker)

```bash
cd ml-service
python -m venv .venv && . .venv/bin/activate    # or .venv\Scripts\activate on Windows
pip install -r requirements.txt
cp .env.example .env  # edit MONGO_URI to your local Mongo
uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload
```

The first boot will download the SentenceTransformer weights (~80 MB)
into `data/hf-cache/`.

## Docker

The service is wired into `docker-compose.yml` at the repo root:

```bash
docker compose up ml-service
```

The Node `api` service already injects `ML_SERVICE_URL=http://ml-service:8000`
when both containers are on the same compose network.

## How to enable / disable

* **Enable:** set `ML_SERVICE_URL` (and matching `ML_SERVICE_API_KEY`) in the
  Node backend's env. The `idealMatch` flow + swipe/accept/reject all start
  hitting the service automatically.
* **Disable:** unset `ML_SERVICE_URL`. The Node backend reverts to its
  legacy one-hot cosine ideal-match service with zero code changes.

## Index lifecycle

* On boot the service calls `rebuild_from_mongo()` which fetches every
  active, profile-complete user, embeds their bio, and builds the FAISS
  index. This blocks `/v1/recommend` until it finishes (typically <30s for
  10k users on CPU).
* To refresh after profile edits/new signups, POST `/v1/admin/rebuild`.
  Reasonable schedule: hourly or on a profile-update webhook.
* The dynamic per-user embeddings (driven by `/v1/event`) live in memory
  only — restarting the service resets them. A persistence layer can be
  added later by dumping `state.dynamic_store` to disk.

## What the algorithm does NOT do yet

The original `INDUSTRIAL_MATCHMAKER.py` defines three supervised pieces —
Two-Tower contrastive, NeuralRanker BPR, SASRec — that need labeled swipe
data to train. At MVP we don't have enough of that data, so these are kept
in `scripts/original_matchmaker.py` for the future training pipeline but
are not loaded at boot. The training notebook (`notebooks/training.ipynb`)
contains the end-to-end workflow.

When you collect enough swipe labels, the path forward is:

1. Run the notebook against a dump of `users` + `likes` to train the
   ranker and serialize weights to `data/ranker.pt`.
2. Add a re-ranking stage in `state.MatchmakerState.recommend` that runs
   the top-K from FAISS through the ranker before applying the bandit.
