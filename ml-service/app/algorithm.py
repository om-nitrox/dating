"""
Industrial matchmaking algorithm — refactored from INDUSTRIAL_MATCHMAKER.py
to be MongoDB-driven instead of CSV-driven.

Pipeline:
  1. SentenceTransformer embeds the personality bio (built from name + bio
     + interests + prompts + jobTitle + religion + politics + education
     + hometown + intent).
  2. FAISS IVFFlat (inner-product on L2-normalized vectors = cosine) does
     ANN retrieval to fetch top-K candidates per query.
  3. DynamicUserEmbedding evolves each user's vector based on swipe events
     (time-decayed EMA). The fused embedding (long-term + session) is the
     actual query vector at recommendation time.
  4. ThompsonSamplingBandit adds exploration bonus to break filter bubbles.
  5. PerfectMatchEngine selects daily (top-1) and weekly (safe/diverse/
     exploration) elite matches.
  6. ExplainabilityEngine generates human-readable reasons.

The supervised pieces from the original (Two-Tower contrastive, NeuralRanker
BPR, SASRec) are intentionally NOT loaded at boot — they require labeled
swipe data we don't have at MVP. The training script in `scripts/` can
produce them later and they can be plugged in via a re-ranking stage.
"""
from __future__ import annotations

import math
import time
import logging
from collections import defaultdict, deque
from dataclasses import dataclass
from pathlib import Path
from typing import Any, Dict, List, Optional, Tuple

import numpy as np

logger = logging.getLogger("ml.algorithm")


# ============================================================
# Personality embedder — wraps SentenceTransformer
# ============================================================
class PersonalityEmbedder:
    """Semantic personality embedding. Lazy-loads SentenceTransformer."""

    def __init__(self, model_name: str = "all-MiniLM-L6-v2"):
        self.model_name = model_name
        self.model = None

    def load_model(self) -> None:
        if self.model is not None:
            return
        from sentence_transformers import SentenceTransformer
        logger.info("Loading SentenceTransformer: %s", self.model_name)
        self.model = SentenceTransformer(self.model_name)

    def embed_batch(
        self,
        texts: List[str],
        batch_size: int = 256,
        show_progress: bool = False,
    ) -> np.ndarray:
        """Embed a list of texts. Returns L2-normalized (N, D) float32."""
        self.load_model()
        emb = self.model.encode(
            texts,
            batch_size=batch_size,
            show_progress_bar=show_progress,
            convert_to_numpy=True,
            normalize_embeddings=True,
        )
        return emb.astype(np.float32)

    def embed_single(self, text: str) -> np.ndarray:
        self.load_model()
        return self.model.encode(
            [text or ""], normalize_embeddings=True, convert_to_numpy=True
        )[0].astype(np.float32)


# ============================================================
# FAISS retrieval — IVFFlat for MVP, HNSW for scale
# ============================================================
class FAISSRetrievalEngine:
    """ANN retrieval over the user embedding matrix."""

    def __init__(self, dim: int):
        self.dim = dim
        self.index = None
        self.user_ids: Optional[np.ndarray] = None

    def build(self, embeddings: np.ndarray, user_ids: np.ndarray, nlist: int = 100) -> None:
        import faiss

        n, d = embeddings.shape
        if d != self.dim:
            raise ValueError(f"Embedding dim {d} != configured {self.dim}")
        self.user_ids = np.asarray(user_ids)

        # IVF needs at least nlist training points; fall back to flat if tiny.
        if n < max(nlist, 39):
            self.index = faiss.IndexFlatIP(d)
            self.index.add(embeddings)
            logger.info("FAISS Flat index built (small corpus): %d vectors", n)
            return

        quantizer = faiss.IndexFlatIP(d)
        effective_nlist = max(2, min(nlist, n // 10))
        self.index = faiss.IndexIVFFlat(quantizer, d, effective_nlist, faiss.METRIC_INNER_PRODUCT)
        self.index.train(embeddings)
        self.index.add(embeddings)
        self.index.nprobe = min(10, effective_nlist)
        logger.info("FAISS IVFFlat index built: %d vectors, nlist=%d", n, effective_nlist)

    def search(self, query: np.ndarray, k: int = 100) -> Tuple[np.ndarray, np.ndarray]:
        if self.index is None or self.user_ids is None:
            raise RuntimeError("Index not built")
        q = query.reshape(1, -1).astype(np.float32)
        # FAISS clips k to ntotal internally; double-cap to silence the warning.
        k = min(k, self.index.ntotal)
        distances, indices = self.index.search(q, k)
        # Filter -1 (empty result) entries.
        ids = []
        scores = []
        for idx, dist in zip(indices[0], distances[0]):
            if idx < 0:
                continue
            ids.append(self.user_ids[idx])
            scores.append(float(dist))
        return np.asarray(scores), np.asarray(ids)

    def save(self, path: Path) -> None:
        import faiss
        faiss.write_index(self.index, str(path))

    def load(self, path: Path, user_ids: np.ndarray) -> None:
        import faiss
        self.index = faiss.read_index(str(path))
        self.user_ids = np.asarray(user_ids)


# ============================================================
# Dynamic per-user embedding (online, time-decayed)
# ============================================================
@dataclass
class BehavioralEvent:
    user_id: str
    target_id: str
    event_type: str  # right_swipe, left_swipe, match, message, reply, ghost, unmatch
    timestamp: float
    weight: float = 1.0


class DynamicUserEmbedding:
    """Evolving user embedding: long-term EMA + session deque."""

    EVENT_WEIGHTS = {
        "right_swipe": 1.0,
        "match": 2.0,
        "message": 1.5,
        "reply": 2.0,
        "left_swipe": -0.5,
        "ghost": -0.3,
        "unmatch": -1.0,
    }
    SESSION_WINDOW = 20
    MAX_HISTORY = 200

    def __init__(self, user_id: str, base_embedding: np.ndarray, half_life_days: float):
        self.user_id = user_id
        self.half_life_days = half_life_days
        self.long_term: np.ndarray = base_embedding.copy().astype(np.float32)
        self.session: deque = deque(maxlen=self.SESSION_WINDOW)
        self.history: deque = deque(maxlen=self.MAX_HISTORY)
        self.pref_memory: Dict[str, float] = defaultdict(float)
        self.total_swipes: int = 0
        self.right_swipes: int = 0
        self.ideal_match_unlocked: bool = False

    def _time_decay(self, timestamp: float) -> float:
        dt_days = (time.time() - timestamp) / 86400.0
        return math.pow(2.0, -dt_days / self.half_life_days)

    def update(self, event: BehavioralEvent, candidate_embedding: np.ndarray) -> None:
        base_w = self.EVENT_WEIGHTS.get(event.event_type, 0.0)
        effective_w = base_w * self._time_decay(event.timestamp)

        self.session.append((candidate_embedding.copy(), effective_w))
        self.history.append((event.target_id, event.event_type, event.timestamp, effective_w))

        self.total_swipes += 1
        if event.event_type == "right_swipe":
            self.right_swipes += 1

        if effective_w > 0:
            alpha = min(0.1, abs(effective_w) * 0.05)
            self.long_term = (1 - alpha) * self.long_term + alpha * candidate_embedding
            norm = np.linalg.norm(self.long_term)
            if norm > 0:
                self.long_term /= norm

    def check_ideal_unlock(self, min_swipes: int, min_right: int) -> bool:
        if self.total_swipes >= min_swipes or self.right_swipes >= min_right:
            self.ideal_match_unlocked = True
        return self.ideal_match_unlocked

    def get_session_embedding(self) -> np.ndarray:
        if not self.session:
            return self.long_term.copy()
        embs, weights = zip(*self.session)
        embs = np.stack(embs)
        w = np.array(weights, dtype=np.float32)
        pos_mask = w > 0
        if pos_mask.sum() == 0:
            return self.long_term.copy()
        w_pos = w[pos_mask]
        w_pos = w_pos / w_pos.sum()
        session_emb = (embs[pos_mask] * w_pos[:, None]).sum(0)
        n = np.linalg.norm(session_emb)
        return session_emb / n if n > 0 else session_emb

    def get_fused_embedding(self, alpha: float = 0.7) -> np.ndarray:
        lt = self.long_term
        st = self.get_session_embedding()
        fused = alpha * lt + (1 - alpha) * st
        n = np.linalg.norm(fused)
        return fused / n if n > 0 else fused

    def get_seen_ids(self) -> set:
        return {h[0] for h in self.history}


class DynamicUserEmbeddingStore:
    """In-memory store keyed by string user_id (MongoDB ObjectId stringified)."""

    def __init__(self, half_life_days: float, min_swipes: int, min_right: int):
        self.half_life_days = half_life_days
        self.min_swipes = min_swipes
        self.min_right = min_right
        self.store: Dict[str, DynamicUserEmbedding] = {}

    def init_user(self, user_id: str, base_embedding: np.ndarray) -> None:
        if user_id not in self.store:
            self.store[user_id] = DynamicUserEmbedding(user_id, base_embedding, self.half_life_days)

    def get(self, user_id: str) -> Optional[DynamicUserEmbedding]:
        return self.store.get(user_id)

    def update(self, event: BehavioralEvent, candidate_emb: np.ndarray) -> None:
        dyn = self.store.get(event.user_id)
        if dyn is None:
            return
        dyn.update(event, candidate_emb)
        dyn.check_ideal_unlock(self.min_swipes, self.min_right)

    def replace_long_term(self, user_id: str, embedding: np.ndarray) -> None:
        dyn = self.store.get(user_id)
        if dyn is None:
            return
        dyn.long_term = embedding.copy().astype(np.float32)


# ============================================================
# Thompson Sampling bandit (cold-start + filter-bubble break)
# ============================================================
class ThompsonSamplingBandit:
    def __init__(self, alpha: float = 1.0, beta: float = 1.0):
        self.alpha = alpha
        self.beta = beta
        self.stats: Dict[Tuple[str, str], List[float]] = defaultdict(
            lambda: [self.alpha, self.beta]
        )

    def sample_score(self, user_id: str, cand_id: str) -> float:
        a, b = self.stats[(user_id, cand_id)]
        return float(np.random.beta(a, b))

    def update(self, user_id: str, cand_id: str, success: bool) -> None:
        key = (user_id, cand_id)
        if success:
            self.stats[key][0] += 1
        else:
            self.stats[key][1] += 1

    def rank_with_exploration(
        self,
        user_id: str,
        cand_ids: List[str],
        base_scores: np.ndarray,
        explore_weight: float = 0.2,
    ) -> np.ndarray:
        thompson = np.array([self.sample_score(user_id, cid) for cid in cand_ids])
        return (1 - explore_weight) * base_scores + explore_weight * thompson


# ============================================================
# Perfect Match Engine — daily + weekly elite matches
# ============================================================
class PerfectMatchEngine:
    def __init__(self):
        pass

    def select_daily_match(
        self,
        user_emb: np.ndarray,
        cand_embs: np.ndarray,
        cand_ids: np.ndarray,
        seen_ids: set,
        eligible_mask: Optional[np.ndarray] = None,
    ) -> Optional[str]:
        if eligible_mask is None:
            eligible_mask = np.ones(len(cand_ids), dtype=bool)
        unseen_mask = np.array([cid not in seen_ids for cid in cand_ids])
        mask = unseen_mask & eligible_mask
        if mask.sum() == 0:
            return None
        embs_u = cand_embs[mask]
        ids_u = cand_ids[mask]
        sims = (user_emb @ embs_u.T).flatten()
        return str(ids_u[int(sims.argmax())])

    def select_weekly_matches(
        self,
        user_emb: np.ndarray,
        cand_embs: np.ndarray,
        cand_ids: np.ndarray,
        seen_ids: set,
        eligible_mask: Optional[np.ndarray] = None,
    ) -> List[Tuple[str, str]]:
        """Returns [(match_id, type)] where type in safe/diverse/exploration."""
        if eligible_mask is None:
            eligible_mask = np.ones(len(cand_ids), dtype=bool)
        unseen_mask = np.array([cid not in seen_ids for cid in cand_ids])
        mask = unseen_mask & eligible_mask
        if mask.sum() < 3:
            return []
        embs_u = cand_embs[mask]
        ids_u = cand_ids[mask]
        sims = (user_emb @ embs_u.T).flatten()

        safe_idx = int(sims.argmax())
        safe_id = str(ids_u[safe_idx])
        safe_emb = embs_u[safe_idx]

        top_k = min(20, len(sims))
        topk_indices = sims.argsort()[-top_k:]
        diversities = np.array([1.0 - float(safe_emb @ embs_u[i]) for i in topk_indices])
        diverse_local_idx = topk_indices[int(diversities.argmax())]
        diverse_id = str(ids_u[diverse_local_idx])

        p40, p70 = np.percentile(sims, 40), np.percentile(sims, 70)
        mid_mask = (sims > p40) & (sims < p70)
        if mid_mask.sum() == 0:
            explore_idx = int(np.random.choice(len(sims)))
        else:
            explore_idx = int(np.random.choice(np.where(mid_mask)[0]))
        explore_id = str(ids_u[explore_idx])

        types = ["safe", "diverse", "exploration"]
        candidates = [safe_id, diverse_id, explore_id]
        out: List[Tuple[str, str]] = []
        seen_in_out: set = set()
        for tid, tname in zip(candidates, types):
            if tid not in seen_in_out:
                seen_in_out.add(tid)
                out.append((tid, tname))
        return out


# ============================================================
# Explainability — human-readable reasons
# ============================================================
class ExplainabilityEngine:
    def explain(
        self,
        user_bio: str,
        cand_bio: str,
        user_emb: np.ndarray,
        cand_emb: np.ndarray,
        user_features: Dict[str, Any],
        cand_features: Dict[str, Any],
    ) -> Dict[str, Any]:
        reasons: List[str] = []
        sem = float((user_emb * cand_emb).sum())
        if sem > 0.7:
            reasons.append(f"Strong personality match ({sem:.2f})")
        elif sem > 0.5:
            reasons.append(f"Good compatibility ({sem:.2f})")

        user_interests = set((user_features.get("interests") or []))
        cand_interests = set((cand_features.get("interests") or []))
        shared = user_interests & cand_interests
        if shared:
            sample = list(shared)[:4]
            reasons.append(f"Shared interests: {', '.join(sample)}")

        if user_features.get("city") and user_features.get("city") == cand_features.get("city"):
            reasons.append(f"Same city: {user_features.get('city')}")

        if user_features.get("datingIntentions") and user_features.get("datingIntentions") == cand_features.get("datingIntentions"):
            reasons.append("Same dating intent")

        if user_features.get("religion") and user_features.get("religion") == cand_features.get("religion"):
            reasons.append(f"Both are {user_features.get('religion')}")

        if not reasons:
            reasons.append("Interesting profile match")

        return {"reasons": reasons, "similarity_score": sem}
