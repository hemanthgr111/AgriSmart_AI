"""Profile request/response schemas."""

from __future__ import annotations

import uuid
from datetime import datetime

from pydantic import BaseModel, ConfigDict, Field


class ProfileUpdate(BaseModel):
    full_name: str | None = Field(default=None, max_length=120)
    bio: str | None = Field(default=None, max_length=500)


class ProfileResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    email: str | None
    full_name: str | None
    avatar_url: str | None
    bio: str | None
    created_at: datetime
    updated_at: datetime
