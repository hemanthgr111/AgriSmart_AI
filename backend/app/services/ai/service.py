"""Provider-agnostic entry point for the AI assistant."""

from __future__ import annotations

import httpx

from app.core.config import get_settings
from app.schemas.chat import ChatMessage
from app.services.ai import gemini, ollama, openai
from app.services.ai.base import (
    AIError,
    conversation_only,
    language_name,
    system_instruction,
)

_SUPPORTED = {"gemini", "openai", "ollama"}


def active_provider() -> str:
    """Return the configured provider name (lower-case, never empty)."""
    return (get_settings().ai_provider or "none").strip().lower()


def is_configured() -> bool:
    """True when a supported provider is selected."""
    return active_provider() in _SUPPORTED


async def generate_reply(
    messages: list[ChatMessage],
    *,
    locale: str | None = None,
    client: httpx.AsyncClient | None = None,
) -> str:
    """Return the assistant's reply for the given conversation."""
    provider = active_provider()
    if provider in ("", "none"):
        raise AIError("The AI assistant is not configured.", 503)
    if provider not in _SUPPORTED:
        raise AIError(f"Unsupported AI provider: {provider}.", 503)

    conversation = conversation_only(messages)
    if not conversation:
        raise AIError("At least one user message is required.", 400)

    system = system_instruction(locale)

    if provider == "gemini":
        return await gemini.complete(conversation, system, client=client)
    if provider == "openai":
        return await openai.complete(conversation, system, client=client)
    return await ollama.complete(conversation, system, client=client)


__all__ = [
    "AIError",
    "active_provider",
    "generate_reply",
    "is_configured",
    "language_name",
    "system_instruction",
]
