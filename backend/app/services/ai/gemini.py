"""Google Gemini provider (generativelanguage.googleapis.com)."""

from __future__ import annotations

import httpx

from app.core.config import get_settings
from app.schemas.chat import ChatMessage
from app.services.ai.base import AIError, post_json

_DEFAULT_MODEL = "gemini-1.5-flash"
_DEFAULT_BASE = "https://generativelanguage.googleapis.com/v1beta"


def _to_contents(messages: list[ChatMessage]) -> list[dict]:
    contents: list[dict] = []
    for message in messages:
        role = "model" if message.role == "assistant" else "user"
        contents.append({"role": role, "parts": [{"text": message.content}]})
    return contents


async def complete(
    messages: list[ChatMessage],
    system: str,
    *,
    client: httpx.AsyncClient | None = None,
) -> str:
    settings = get_settings()
    if not settings.ai_api_key:
        raise AIError("The AI assistant is not configured.", 503)

    base = (settings.ai_base_url or _DEFAULT_BASE).rstrip("/")
    model = settings.ai_model or _DEFAULT_MODEL
    url = f"{base}/models/{model}:generateContent"

    body = {
        "contents": _to_contents(messages),
        "systemInstruction": {"parts": [{"text": system}]},
        "generationConfig": {"maxOutputTokens": settings.ai_max_output_tokens},
    }

    data = await post_json(
        url,
        params={"key": settings.ai_api_key},
        json_body=body,
        client=client,
        timeout=settings.ai_timeout_seconds,
    )

    try:
        return data["candidates"][0]["content"]["parts"][0]["text"].strip()
    except (KeyError, IndexError, TypeError) as exc:
        raise AIError("Unexpected response from the AI provider.", 502) from exc
