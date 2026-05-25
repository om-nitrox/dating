"""Runtime configuration. Reads from environment, with safe defaults for dev."""
from __future__ import annotations

import os
from dataclasses import dataclass, field
from pathlib import Path
from typing import List


def _env(key: str, default: str | None = None) -> str | None:
    val = os.getenv(key)
    return val if val not in (None, "") else default


def _env_int(key: str, default: int) -> int:
    raw = _env(key)
    return int(raw) if raw is not None else default


def _env_float(key: str, default: float) -> float:
    raw = _env(key)
    return float(raw) if raw is not None else default


def _env_list(key: str, default: List[str]) -> List[str]:
    raw = _env(key)
    if raw is None:
        return list(default)
    return [p.strip() for p in raw.split(",") if p.strip()]


@dataclass
class Settings:
    # Mongo
    mongo_uri: str = field(default_factory=lambda: _env("MONGO_URI", "mongodb://localhost:27017/reverse_match"))

    # Service
    host: str = field(default_factory=lambda: _env("HOST", "0.0.0.0"))
    port: int = field(default_factory=lambda: _env_int("PORT", 8000))
    api_key: str = field(default_factory=lambda: _env("ML_SERVICE_API_KEY", ""))
    cors_origins: List[str] = field(
        default_factory=lambda: _env_list("CORS_ORIGINS", ["*"])
    )

    # Embedding model
    embed_model: str = field(default_factory=lambda: _env("EMBED_MODEL", "all-MiniLM-L6-v2"))
    text_embed_dim: int = field(default_factory=lambda: _env_int("TEXT_EMBED_DIM", 384))

    # Persistence
    data_dir: Path = field(default_factory=lambda: Path(_env("DATA_DIR", "/app/data")))

    # Retrieval
    candidates_k: int = field(default_factory=lambda: _env_int("CANDIDATES_K", 100))
    top_k: int = field(default_factory=lambda: _env_int("TOP_K", 20))
    faiss_nlist: int = field(default_factory=lambda: _env_int("FAISS_NLIST", 100))

    # Matchmaking rules
    ideal_match_min_swipes: int = field(default_factory=lambda: _env_int("IDEAL_MATCH_MIN_SWIPES", 20))
    ideal_match_min_right: int = field(default_factory=lambda: _env_int("IDEAL_MATCH_MIN_RIGHT", 10))

    # Bandit
    explore_alpha: float = field(default_factory=lambda: _env_float("EXPLORE_ALPHA", 1.0))
    explore_beta: float = field(default_factory=lambda: _env_float("EXPLORE_BETA", 1.0))
    explore_weight: float = field(default_factory=lambda: _env_float("EXPLORE_WEIGHT", 0.2))

    # Time decay (days)
    time_decay_half_life: float = field(default_factory=lambda: _env_float("TIME_DECAY_HALF_LIFE", 7.0))

    # Refresh
    auto_rebuild_on_boot: bool = field(default_factory=lambda: _env("AUTO_REBUILD_ON_BOOT", "true").lower() == "true")
    rebuild_min_users: int = field(default_factory=lambda: _env_int("REBUILD_MIN_USERS", 1))

    def ensure_data_dir(self) -> None:
        self.data_dir.mkdir(parents=True, exist_ok=True)


settings = Settings()
settings.ensure_data_dir()
