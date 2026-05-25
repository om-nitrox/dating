"""Pydantic request/response schemas."""
from __future__ import annotations

from typing import Any, Dict, List, Optional

from pydantic import BaseModel, Field


class RecommendRequest(BaseModel):
    user_id: str
    k: int = Field(default=20, ge=1, le=100)


class Recommendation(BaseModel):
    candidate_id: str
    score: float
    base_score: float
    reasons: List[str]
    profile: Dict[str, Any]


class RecommendResponse(BaseModel):
    viewer_id: str
    recommendations: List[Recommendation]
    ideal_match_unlocked: bool = False
    total_swipes: int = 0
    right_swipes: int = 0
    reason: Optional[str] = None


class EventRequest(BaseModel):
    user_id: str
    target_id: str
    event_type: str  # right_swipe | left_swipe | match | message | reply | ghost | unmatch
    timestamp: Optional[float] = None


class EventResponse(BaseModel):
    ok: bool
    total_swipes: int = 0
    right_swipes: int = 0
    ideal_match_unlocked: bool = False
    reason: Optional[str] = None


class DailyMatchResponse(BaseModel):
    match: Optional[Dict[str, Any]] = None


class WeeklyMatchesResponse(BaseModel):
    matches: List[Dict[str, Any]]


class RebuildResponse(BaseModel):
    status: str
    users: int
    took_seconds: Optional[float] = None
    reason: Optional[str] = None


class HealthResponse(BaseModel):
    status: str
    ready: bool
    indexed_users: int
    embed_model: str
