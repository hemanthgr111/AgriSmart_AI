"""AI assistant chat schemas."""

from __future__ import annotations

from typing import Literal

from pydantic import BaseModel, Field

ChatRole = Literal["user", "assistant", "system"]


class ChatMessage(BaseModel):
    role: ChatRole
    content: str = Field(min_length=1, max_length=8000)


class ChatRequest(BaseModel):
    messages: list[ChatMessage] = Field(min_length=1, max_length=50)
    locale: str | None = None


class ChatResponse(BaseModel):
    reply: str
    provider: str
