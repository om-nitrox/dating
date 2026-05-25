"""
Runtime state: the live pipeline. One instance per process.

Holds the embedding matrix, FAISS index, dynamic per-user store, bandit,
and the engines. `rebuild_from_mongo` (re)populates everything from the
current `users` collection — call it on boot and via the admin endpoint.
"""
from __future__ import annotations

import logging
import threading
import time
from dataclasses import dataclass
from typing import Any, Dict, List, Optional, Tuple

import numpy as np

from .adapter import UserRepository, build_bio_text, shape_for_payload, to_string_id
from .algorithm import (
    BehavioralEvent,
    DynamicUserEmbeddingStore,
    ExplainabilityEngine,
    FAISSRetrievalEngine,
    PerfectMatchEngine,
    PersonalityEmbedder,
    ThompsonSamplingBandit,
)
from .config import Settings

logger = logging.getLogger("ml.state")


@dataclass
class IndexSnapshot:
    embeddings: np.ndarray            # (N, D) L2-normalized
    user_ids: np.ndarray              # (N,) string ids in row order
    id_to_idx: Dict[str, int]
    user_docs: Dict[str, Dict[str, Any]]   # id -> full user document
    user_genders: np.ndarray          # (N,) gender per row (for filtering)
    built_at: float


class MatchmakerState:
    """Thread-safe holder for the live pipeline."""

    def __init__(self, settings: Settings):
        self.settings = settings
        self._lock = threading.RLock()
        self.embedder = PersonalityEmbedder(settings.embed_model)
        self.faiss = FAISSRetrievalEngine(settings.text_embed_dim)
        self.dynamic_store = DynamicUserEmbeddingStore(
            half_life_days=settings.time_decay_half_life,
            min_swipes=settings.ideal_match_min_swipes,
            min_right=settings.ideal_match_min_right,
        )
        self.bandit = ThompsonSamplingBandit(settings.explore_alpha, settings.explore_beta)
        self.perfect_match = PerfectMatchEngine()
        self.explainer = ExplainabilityEngine()
        self.snapshot: Optional[IndexSnapshot] = None

    # ----- read helpers (caller must hold or not need the lock) -----
    def is_ready(self) -> bool:
        return self.snapshot is not None and self.snapshot.embeddings.size > 0

    def user_count(self) -> int:
        return 0 if self.snapshot is None else int(self.snapshot.embeddings.shape[0])

    # ----- index lifecycle -----
    def rebuild_from_mongo(self) -> Dict[str, Any]:
        """Full rebuild. Safe to call at any time — swaps state atomically."""
        with self._lock:
            t0 = time.time()
            repo = UserRepository(self.settings.mongo_uri)
            user_docs: Dict[str, Dict[str, Any]] = {}
            ordered_ids: List[str] = []
            bios: List[str] = []
            genders: List[str] = []

            for doc in repo.iter_eligible_users():
                uid = to_string_id(doc["_id"])
                user_docs[uid] = doc
                ordered_ids.append(uid)
                bios.append(build_bio_text(doc))
                genders.append(doc.get("gender") or "")

            n = len(ordered_ids)
            if n < self.settings.rebuild_min_users:
                logger.warning("rebuild_from_mongo: too few users (%d); skipping", n)
                return {"status": "skipped", "users": n, "reason": "below_min_users"}

            embeddings = self.embedder.embed_batch(bios, show_progress=False)
            user_ids_arr = np.asarray(ordered_ids)
            id_to_idx = {uid: i for i, uid in enumerate(ordered_ids)}

            self.faiss.build(embeddings, user_ids_arr, nlist=self.settings.faiss_nlist)

            # Seed dynamic store for users that don't have one yet, and
            # refresh long-term for those that do (without trampling
            # behavioral history).
            for uid in ordered_ids:
                emb = embeddings[id_to_idx[uid]]
                if self.dynamic_store.get(uid) is None:
                    self.dynamic_store.init_user(uid, emb)
                else:
                    # Re-seed long-term if profile content changed; the session
                    # deque + history are kept intact.
                    self.dynamic_store.replace_long_term(uid, emb)

            self.snapshot = IndexSnapshot(
                embeddings=embeddings,
                user_ids=user_ids_arr,
                id_to_idx=id_to_idx,
                user_docs=user_docs,
                user_genders=np.asarray(genders),
                built_at=time.time(),
            )
            elapsed = time.time() - t0
            logger.info("Index rebuilt: %d users in %.2fs", n, elapsed)
            return {"status": "ok", "users": n, "took_seconds": round(elapsed, 3)}

    # ----- recommendation flow -----
    def _eligible_mask(self, viewer_doc: Dict[str, Any]) -> np.ndarray:
        """Mask over `snapshot.user_ids` of candidates matching gender preference."""
        repo = UserRepository(self.settings.mongo_uri)
        target = set(repo.resolve_target_genders(viewer_doc))
        return np.isin(self.snapshot.user_genders, list(target))

    def _viewer_dynamic(self, viewer_id: str, viewer_doc: Optional[Dict[str, Any]]) -> Any:
        """Get dynamic embedding; seed from Mongo bio if not in store yet."""
        dyn = self.dynamic_store.get(viewer_id)
        if dyn is not None:
            return dyn
        # Viewer absent from snapshot (e.g. brand-new account, not yet indexed):
        # build their embedding on-the-fly without adding to the corpus.
        repo = UserRepository(self.settings.mongo_uri)
        doc = viewer_doc or repo.get_user(viewer_id)
        if not doc:
            return None
        bio = build_bio_text(doc)
        emb = self.embedder.embed_single(bio)
        self.dynamic_store.init_user(viewer_id, emb)
        return self.dynamic_store.get(viewer_id)

    def recommend(self, viewer_id: str, k: int) -> Dict[str, Any]:
        if not self.is_ready():
            return {"viewer_id": viewer_id, "recommendations": [], "reason": "index_empty"}
        with self._lock:
            snap = self.snapshot
            repo = UserRepository(self.settings.mongo_uri)
            viewer_doc = repo.get_user(viewer_id) or snap.user_docs.get(viewer_id)
            if not viewer_doc:
                return {"viewer_id": viewer_id, "recommendations": [], "reason": "viewer_not_found"}

            dyn = self._viewer_dynamic(viewer_id, viewer_doc)
            if dyn is None:
                return {"viewer_id": viewer_id, "recommendations": [], "reason": "viewer_not_indexable"}

            query_emb = dyn.get_fused_embedding()

            # FAISS retrieval — overfetch to leave room after filtering.
            _, cand_ids = self.faiss.search(query_emb, k=max(self.settings.candidates_k, k * 4))

            # Filter: seen, blocked/matched/liked, self, gender preference.
            excluded = repo.get_excluded_ids(viewer_id) | dyn.get_seen_ids()
            target_genders = set(repo.resolve_target_genders(viewer_doc))

            kept_ids: List[str] = []
            for cid in cand_ids:
                cid_s = str(cid)
                if cid_s in excluded:
                    continue
                idx = snap.id_to_idx.get(cid_s)
                if idx is None:
                    continue
                if snap.user_genders[idx] not in target_genders:
                    continue
                kept_ids.append(cid_s)
                if len(kept_ids) >= k * 4:
                    break

            if not kept_ids:
                return {"viewer_id": viewer_id, "recommendations": [], "reason": "no_candidates"}

            cand_embs = np.stack([snap.embeddings[snap.id_to_idx[cid]] for cid in kept_ids])
            base_scores = (query_emb @ cand_embs.T).flatten()
            final_scores = self.bandit.rank_with_exploration(
                viewer_id, kept_ids, base_scores, explore_weight=self.settings.explore_weight
            )

            order = final_scores.argsort()[::-1][:k]
            viewer_features = shape_for_payload(viewer_doc)
            viewer_bio = build_bio_text(viewer_doc)

            recs: List[Dict[str, Any]] = []
            for idx in order:
                cid = kept_ids[idx]
                cand_doc = snap.user_docs.get(cid) or repo.get_user(cid)
                if not cand_doc:
                    continue
                cand_emb = snap.embeddings[snap.id_to_idx[cid]]
                cand_bio = build_bio_text(cand_doc)
                exp = self.explainer.explain(
                    viewer_bio,
                    cand_bio,
                    query_emb,
                    cand_emb,
                    viewer_features,
                    shape_for_payload(cand_doc),
                )
                recs.append({
                    "candidate_id": cid,
                    "score": float(final_scores[idx]),
                    "base_score": float(base_scores[idx]),
                    "reasons": exp["reasons"],
                    "profile": shape_for_payload(cand_doc),
                })

            return {
                "viewer_id": viewer_id,
                "recommendations": recs,
                "ideal_match_unlocked": dyn.ideal_match_unlocked,
                "total_swipes": dyn.total_swipes,
                "right_swipes": dyn.right_swipes,
            }

    # ----- daily / weekly elite -----
    def _eligible_full(self, viewer_id: str, viewer_doc: Dict[str, Any]) -> Tuple[np.ndarray, set]:
        repo = UserRepository(self.settings.mongo_uri)
        excluded = repo.get_excluded_ids(viewer_id)
        target_genders = set(repo.resolve_target_genders(viewer_doc))
        mask = np.array([
            (self.snapshot.user_ids[i] not in excluded)
            and (self.snapshot.user_genders[i] in target_genders)
            for i in range(len(self.snapshot.user_ids))
        ])
        return mask, excluded

    def daily_match(self, viewer_id: str) -> Optional[Dict[str, Any]]:
        if not self.is_ready():
            return None
        with self._lock:
            snap = self.snapshot
            repo = UserRepository(self.settings.mongo_uri)
            viewer_doc = repo.get_user(viewer_id) or snap.user_docs.get(viewer_id)
            if not viewer_doc:
                return None
            dyn = self._viewer_dynamic(viewer_id, viewer_doc)
            if dyn is None or not dyn.ideal_match_unlocked:
                return None
            mask, _ = self._eligible_full(viewer_id, viewer_doc)
            query_emb = dyn.get_fused_embedding()
            match_id = self.perfect_match.select_daily_match(
                query_emb, snap.embeddings, snap.user_ids, dyn.get_seen_ids(), mask
            )
            if not match_id:
                return None
            cand_doc = snap.user_docs.get(match_id) or repo.get_user(match_id)
            if not cand_doc:
                return None
            exp = self.explainer.explain(
                build_bio_text(viewer_doc),
                build_bio_text(cand_doc),
                query_emb,
                snap.embeddings[snap.id_to_idx[match_id]],
                shape_for_payload(viewer_doc),
                shape_for_payload(cand_doc),
            )
            return {
                "match_id": match_id,
                "type": "daily_perfect_match",
                "reasons": exp["reasons"],
                "profile": shape_for_payload(cand_doc),
            }

    def weekly_matches(self, viewer_id: str) -> List[Dict[str, Any]]:
        if not self.is_ready():
            return []
        with self._lock:
            snap = self.snapshot
            repo = UserRepository(self.settings.mongo_uri)
            viewer_doc = repo.get_user(viewer_id) or snap.user_docs.get(viewer_id)
            if not viewer_doc:
                return []
            dyn = self._viewer_dynamic(viewer_id, viewer_doc)
            if dyn is None or not dyn.ideal_match_unlocked:
                return []
            mask, _ = self._eligible_full(viewer_id, viewer_doc)
            query_emb = dyn.get_fused_embedding()
            picks = self.perfect_match.select_weekly_matches(
                query_emb, snap.embeddings, snap.user_ids, dyn.get_seen_ids(), mask
            )
            out: List[Dict[str, Any]] = []
            for mid, mtype in picks:
                cand_doc = snap.user_docs.get(mid) or repo.get_user(mid)
                if not cand_doc:
                    continue
                out.append({
                    "match_id": mid,
                    "type": mtype,
                    "profile": shape_for_payload(cand_doc),
                })
            return out

    # ----- behavioral events -----
    def record_event(
        self,
        user_id: str,
        target_id: str,
        event_type: str,
        timestamp: Optional[float] = None,
    ) -> Dict[str, Any]:
        if not self.is_ready():
            return {"ok": False, "reason": "index_empty"}
        with self._lock:
            snap = self.snapshot
            event = BehavioralEvent(
                user_id=user_id,
                target_id=target_id,
                event_type=event_type,
                timestamp=timestamp if timestamp is not None else time.time(),
            )
            # Resolve candidate embedding. Fall back to single-shot embed if
            # the target isn't in the corpus (rare race: new user just added).
            idx = snap.id_to_idx.get(target_id)
            if idx is not None:
                cand_emb = snap.embeddings[idx]
            else:
                repo = UserRepository(self.settings.mongo_uri)
                doc = repo.get_user(target_id)
                if not doc:
                    return {"ok": False, "reason": "target_not_found"}
                cand_emb = self.embedder.embed_single(build_bio_text(doc))

            # Seed the user's dynamic embedding if it doesn't exist yet.
            if self.dynamic_store.get(user_id) is None:
                repo = UserRepository(self.settings.mongo_uri)
                viewer_doc = repo.get_user(user_id)
                if viewer_doc is None:
                    return {"ok": False, "reason": "user_not_found"}
                base = self.embedder.embed_single(build_bio_text(viewer_doc))
                self.dynamic_store.init_user(user_id, base)

            self.dynamic_store.update(event, cand_emb)
            self.bandit.update(user_id, target_id, event_type in {"right_swipe", "match", "reply"})

            dyn = self.dynamic_store.get(user_id)
            return {
                "ok": True,
                "total_swipes": dyn.total_swipes,
                "right_swipes": dyn.right_swipes,
                "ideal_match_unlocked": dyn.ideal_match_unlocked,
            }
