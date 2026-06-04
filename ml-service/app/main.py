"""FastAPI entrypoint."""
from __future__ import annotations

import logging
import os
import threading
from contextlib import asynccontextmanager

from fastapi import Depends, FastAPI, Header, HTTPException, status
from fastapi.middleware.cors import CORSMiddleware

from .config import settings
from .schemas import (
    DailyMatchResponse,
    EventRequest,
    EventResponse,
    HealthResponse,
    RebuildResponse,
    RecommendRequest,
    RecommendResponse,
    WeeklyMatchesResponse,
)
from .state import MatchmakerState

logging.basicConfig(
    level=os.getenv("LOG_LEVEL", "INFO").upper(),
    format="%(asctime)s [%(levelname)s] %(name)s: %(message)s",
)
logger = logging.getLogger("ml.main")

state = MatchmakerState(settings)


def require_api_key(x_api_key: str = Header(default="")) -> None:
    """Reject requests missing the shared secret. Disabled when no key is set."""
    if not settings.api_key:
        return
    if x_api_key != settings.api_key:
        raise HTTPException(status.HTTP_401_UNAUTHORIZED, "invalid api key")


def _boot_rebuild() -> None:
    try:
        result = state.rebuild_from_mongo()
        logger.info("Boot index built: %s", result)
    except Exception as e:
        logger.exception("Boot index build failed: %s", e)


@asynccontextmanager
async def lifespan(app: FastAPI):
    if settings.auto_rebuild_on_boot:
        # Build the index in a daemon thread so uvicorn binds the port and
        # reports startup-complete immediately. AppSail kills instances that
        # don't start listening within its startup window, and a synchronous
        # rebuild (model load + embedding) overruns it. The snapshot swaps in
        # atomically once built; /health reports ready=false until then.
        threading.Thread(target=_boot_rebuild, name="boot-rebuild", daemon=True).start()
    yield


app = FastAPI(title="Reverse Match ML Service", version="0.1.0", lifespan=lifespan)

app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.cors_origins,
    allow_methods=["*"],
    allow_headers=["*"],
)


@app.get("/health", response_model=HealthResponse)
def health() -> HealthResponse:
    return HealthResponse(
        status="ok",
        ready=state.is_ready(),
        indexed_users=state.user_count(),
        embed_model=settings.embed_model,
    )


@app.post(
    "/v1/recommend",
    response_model=RecommendResponse,
    dependencies=[Depends(require_api_key)],
)
def recommend(req: RecommendRequest) -> RecommendResponse:
    result = state.recommend(
        req.user_id,
        k=req.k,
        allowed_candidate_ids=req.allowed_candidate_ids,
    )
    return RecommendResponse(**result)


@app.post(
    "/v1/event",
    response_model=EventResponse,
    dependencies=[Depends(require_api_key)],
)
def event(req: EventRequest) -> EventResponse:
    result = state.record_event(
        req.user_id, req.target_id, req.event_type, req.timestamp
    )
    return EventResponse(**result)


@app.get(
    "/v1/daily-match/{user_id}",
    response_model=DailyMatchResponse,
    dependencies=[Depends(require_api_key)],
)
def daily_match(user_id: str) -> DailyMatchResponse:
    return DailyMatchResponse(match=state.daily_match(user_id))


@app.get(
    "/v1/weekly-matches/{user_id}",
    response_model=WeeklyMatchesResponse,
    dependencies=[Depends(require_api_key)],
)
def weekly_matches(user_id: str) -> WeeklyMatchesResponse:
    return WeeklyMatchesResponse(matches=state.weekly_matches(user_id))


@app.post(
    "/v1/admin/rebuild",
    response_model=RebuildResponse,
    dependencies=[Depends(require_api_key)],
)
def rebuild() -> RebuildResponse:
    return RebuildResponse(**state.rebuild_from_mongo())
