"""
MongoDB adapter — reads our `User` collection and gender-preference rules,
returns the inputs the algorithm wants.

Source of truth for taxonomies/fields: backend/src/models/User.js + backend/src/domain/taxonomies.js.
"""
from __future__ import annotations

import logging
from typing import Any, Dict, Iterable, List, Optional, Set, Tuple

from bson import ObjectId
from pymongo import MongoClient
from pymongo.collection import Collection
from pymongo.database import Database

logger = logging.getLogger("ml.adapter")


def _mongo_db(uri: str) -> Database:
    client = MongoClient(uri, serverSelectionTimeoutMS=8000)
    # Pull DB name out of the URI's path component (last segment).
    db_name = uri.rsplit("/", 1)[-1].split("?")[0] or "reverse_match"
    return client[db_name]


def build_bio_text(user: Dict[str, Any]) -> str:
    """
    Compose a personality string from our User document. The
    SentenceTransformer is trained on natural language, so we stitch the
    profile into a coherent sentence-like blob instead of feeding raw enum
    values.
    """
    parts: List[str] = []

    if user.get("bio"):
        parts.append(str(user["bio"]))

    name = user.get("name")
    age = user.get("age")
    gender = user.get("gender")
    if name and age:
        parts.append(f"{name}, {age} years old.")

    if user.get("hometown"):
        parts.append(f"From {user['hometown']}.")

    if user.get("jobTitle") and user.get("workplace"):
        parts.append(f"Works as {user['jobTitle']} at {user['workplace']}.")
    elif user.get("jobTitle"):
        parts.append(f"Works as {user['jobTitle']}.")

    if user.get("education"):
        parts.append(f"Studied at {user['education']}.")

    interests = user.get("interests") or []
    if interests:
        parts.append("Interests: " + ", ".join(str(i) for i in interests[:15]) + ".")

    languages = user.get("languages") or []
    if languages:
        parts.append("Languages: " + ", ".join(str(l) for l in languages) + ".")

    if user.get("religion"):
        parts.append(f"Religion: {user['religion']}.")
    if user.get("politics"):
        parts.append(f"Politics: {user['politics']}.")

    if user.get("datingIntentions"):
        intent_map = {
            "life_partner": "looking for a life partner",
            "long_term": "looking for a long-term relationship",
            "long_term_open_short": "looking for long-term but open to short-term",
            "short_term_open_long": "looking for short-term but open to long-term",
            "short_term": "looking for something short-term",
            "new_friends": "looking for new friends",
            "figuring_out": "figuring it out",
        }
        phrase = intent_map.get(user["datingIntentions"], str(user["datingIntentions"]))
        parts.append(f"Currently {phrase}.")

    prompts = user.get("prompts") or []
    for p in prompts[:3]:
        q = p.get("question") if isinstance(p, dict) else None
        a = p.get("answer") if isinstance(p, dict) else None
        if q and a:
            parts.append(f"{q} {a}")

    text = " ".join(parts).strip()
    return text[:2048] if text else (gender or "person")


def to_string_id(value: Any) -> str:
    if isinstance(value, ObjectId):
        return str(value)
    return str(value)


class UserRepository:
    """Read-only repository for the algorithm's needs."""

    USER_FIELDS = {
        "_id": 1,
        "name": 1,
        "age": 1,
        "gender": 1,
        "bio": 1,
        "interests": 1,
        "languages": 1,
        "religion": 1,
        "politics": 1,
        "datingIntentions": 1,
        "relationshipType": 1,
        "exercise": 1,
        "children": 1,
        "familyPlans": 1,
        "vices": 1,
        "hometown": 1,
        "jobTitle": 1,
        "workplace": 1,
        "education": 1,
        "prompts": 1,
        "preferences": 1,
        "location": 1,
        "isActive": 1,
        "isProfileComplete": 1,
    }

    def __init__(self, mongo_uri: str):
        self.db = _mongo_db(mongo_uri)

    @property
    def users(self) -> Collection:
        return self.db["users"]

    @property
    def likes(self) -> Collection:
        return self.db["likes"]

    @property
    def blocks(self) -> Collection:
        return self.db["blocks"]

    @property
    def matches(self) -> Collection:
        return self.db["matches"]

    # -------- index population --------
    def iter_eligible_users(self) -> Iterable[Dict[str, Any]]:
        """Active, profile-complete users. Used for FAISS corpus."""
        cursor = self.users.find(
            {"isActive": True, "isProfileComplete": True},
            self.USER_FIELDS,
        ).batch_size(500)
        for doc in cursor:
            yield doc

    def get_user(self, user_id: str) -> Optional[Dict[str, Any]]:
        try:
            oid = ObjectId(user_id)
        except Exception:
            return None
        return self.users.find_one({"_id": oid}, self.USER_FIELDS)

    def get_users(self, user_ids: List[str]) -> Dict[str, Dict[str, Any]]:
        try:
            oids = [ObjectId(uid) for uid in user_ids]
        except Exception:
            return {}
        docs = self.users.find({"_id": {"$in": oids}}, self.USER_FIELDS)
        return {to_string_id(d["_id"]): d for d in docs}

    # -------- exclusion + targeting --------
    def get_excluded_ids(self, user_id: str) -> Set[str]:
        """Already-interacted, blocked, matched ids — same logic as backend."""
        try:
            oid = ObjectId(user_id)
        except Exception:
            return set()
        out: Set[str] = {user_id}
        for like in self.likes.find({"fromUser": oid}, {"toUser": 1}):
            out.add(to_string_id(like["toUser"]))
        for b in self.blocks.find(
            {"$or": [{"blocker": oid}, {"blocked": oid}]},
            {"blocker": 1, "blocked": 1},
        ):
            out.add(to_string_id(b["blocker"]))
            out.add(to_string_id(b["blocked"]))
        for m in self.matches.find({"users": oid}, {"users": 1}):
            for u in m.get("users", []):
                out.add(to_string_id(u))
        return out

    def resolve_target_genders(self, viewer: Dict[str, Any]) -> List[str]:
        """Mirror of backend/src/services/idealMatch.service.js resolveTargetGenders."""
        pref = (viewer.get("preferences") or {}).get("genderPreference")
        if pref == "men":
            return ["male"]
        if pref == "women":
            return ["female"]
        if pref == "everyone":
            return ["male", "female", "nonbinary"]
        if viewer.get("gender") == "female":
            return ["male"]
        if viewer.get("gender") == "male":
            return ["female"]
        return ["male", "female", "nonbinary"]


def shape_for_payload(user: Dict[str, Any]) -> Dict[str, Any]:
    """Trimmed dict for API responses + explainability lookups."""
    loc = user.get("location") or {}
    return {
        "id": to_string_id(user["_id"]),
        "name": user.get("name"),
        "age": user.get("age"),
        "gender": user.get("gender"),
        "city": loc.get("city"),
        "state": loc.get("state"),
        "interests": user.get("interests") or [],
        "datingIntentions": user.get("datingIntentions"),
        "religion": user.get("religion"),
    }
