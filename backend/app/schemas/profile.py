"""Profile request/response schemas."""

from __future__ import annotations

import re
import uuid
from datetime import datetime

from pydantic import BaseModel, ConfigDict, Field, field_validator

# Usernames are user-visible handles; keep them to a safe, portable charset.
_USERNAME_RE = re.compile(r"^[A-Za-z0-9_]{3,30}$")
_SUPPORTED_LANGUAGES = {"en", "hi", "bn", "mr", "te", "ta", "gu", "ur", "kn"}


class ProfileUpdate(BaseModel):
    full_name: str | None = Field(default=None, max_length=120)
    bio: str | None = Field(default=None, max_length=500)
    username: str | None = Field(default=None, max_length=120)
    preferred_language: str | None = Field(default=None, max_length=20)

    @field_validator("username")
    @classmethod
    def _normalise_username(cls, value: str | None) -> str | None:
        if value is None:
            return None
        candidate = value.strip()
        if not candidate:
            return None
        if not _USERNAME_RE.match(candidate):
            raise ValueError(
                "Username must be 3-30 characters using letters, numbers or underscore."
            )
        return candidate

    @field_validator("preferred_language")
    @classmethod
    def _validate_language(cls, value: str | None) -> str | None:
        if value is None:
            return None
        candidate = value.strip()
        if not candidate:
            return None
        if candidate.split("-")[0].lower() not in _SUPPORTED_LANGUAGES:
            raise ValueError("Unsupported preferred_language.")
        return candidate


class ProfileResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    email: str | None
    full_name: str | None
    avatar_url: str | None
    bio: str | None = Field(default=None, max_length=500)
    username: str | None = None
    preferred_language: str | None = None
    created_at: datetime
    updated_at: datetime
