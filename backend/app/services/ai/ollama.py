"""Ollama provider (local or self-hosted; no API key by default)."""

from __future__ import annotations

import httpx

from app.core.config import get_settings
from app.schemas.chat import ChatMessage
from app.services.ai.base import AIError, post_json

_DEFAULT_MODEL = "llama3.1"
_DEFAULT_BASE = "http://localhost:11434"


async def complete(
    messages: list[ChatMessage],
    system: str,
    *,
    client: httpx.AsyncClient | None = None,
) -> str:
    settings = get_settings()

    base = (settings.ai_base_url or _DEFAULT_BASE).rstrip("/")
    url = f"{base}/api/chat"

    payload = [{"role": "system", "content": system}]
    payload += [
        {"role": message.role, "content": message.content} for message in messages
    ]
    body = {
        "model": settings.ai_model or _DEFAULT_MODEL,
        "messages": payload,
        "stream": False,
        "options": {"num_predict": settings.ai_max_output_tokens},
    }

    data = await post_json(
        url, json_body=body, client=client, timeout=settings.ai_timeout_seconds
    )

    try:
        return data["message"]["content"].strip()
    except (KeyError, TypeError) as exc:
        raise AIError("Unexpected response from the AI provider.", 502) from exc
