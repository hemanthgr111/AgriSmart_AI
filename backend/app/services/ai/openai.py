"""OpenAI-compatible provider (chat completions)."""

from __future__ import annotations

import httpx

from app.core.config import get_settings
from app.schemas.chat import ChatMessage
from app.services.ai.base import AIError, post_json

_DEFAULT_MODEL = "gpt-4o-mini"
_DEFAULT_BASE = "https://api.openai.com/v1"


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
    url = f"{base}/chat/completions"

    payload = [{"role": "system", "content": system}]
    payload += [
        {"role": message.role, "content": message.content} for message in messages
    ]
    body = {
        "model": settings.ai_model or _DEFAULT_MODEL,
        "messages": payload,
        "max_tokens": settings.ai_max_output_tokens,
    }

    data = await post_json(
        url,
        headers={"Authorization": f"Bearer {settings.ai_api_key}"},
        json_body=body,
        client=client,
        timeout=settings.ai_timeout_seconds,
    )

    try:
        return data["choices"][0]["message"]["content"].strip()
    except (KeyError, IndexError, TypeError) as exc:
        raise AIError("Unexpected response from the AI provider.", 502) from exc
