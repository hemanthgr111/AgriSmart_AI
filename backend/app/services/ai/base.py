"""Shared pieces for AI provider clients.

Every provider takes a list of ``ChatMessage`` plus a system instruction and
returns plain text. The API key (if any) stays server-side. Providers are
selected by ``AI_PROVIDER`` and never fabricate a reply: on any failure an
``AIError`` is raised so the route can respond with an appropriate status.
"""

from __future__ import annotations

from typing import Any

import httpx

from app.schemas.chat import ChatMessage

# Language display names for the supported locales. Used to instruct the model
# to answer in the farmer's chosen language.
_LANGUAGE_NAMES: dict[str, str] = {
    "en": "English",
    "hi": "Hindi",
    "bn": "Bengali",
    "mr": "Marathi",
    "te": "Telugu",
    "ta": "Tamil",
    "gu": "Gujarati",
    "ur": "Urdu",
    "kn": "Kannada",
}

_SYSTEM_TEMPLATE = (
    "You are AgriSmart AI, a practical agriculture assistant for farmers in "
    "India. Help with crops, seeds, soil, irrigation, pests, plant diseases, "
    "weather-related decisions, and post-harvest handling. Be concise, "
    "specific, and use simple language. Prefer low-cost, locally available "
    "solutions and mention safety precautions for any chemical use. If you are "
    "unsure, say so and suggest consulting the local agricultural extension "
    "officer. Always respond in {language}."
)


class AIError(Exception):
    """Raised for any AI-provider failure. Carries an HTTP status."""

    def __init__(self, message: str, status_code: int = 502) -> None:
        super().__init__(message)
        self.message = message
        self.status_code = status_code


def language_name(locale: str | None) -> str:
    """Map a locale code to a display name, defaulting to English."""
    if not locale:
        return "English"
    return _LANGUAGE_NAMES.get(locale.split("-")[0].lower(), "English")


def system_instruction(locale: str | None) -> str:
    """Build the system prompt, requesting the user's language."""
    return _SYSTEM_TEMPLATE.format(language=language_name(locale))


def conversation_only(messages: list[ChatMessage]) -> list[ChatMessage]:
    """Drop any client-supplied system messages (we set our own)."""
    return [message for message in messages if message.role != "system"]


async def post_json(
    url: str,
    *,
    headers: dict[str, str] | None = None,
    json_body: dict[str, Any] | None = None,
    params: dict[str, str] | None = None,
    client: httpx.AsyncClient | None = None,
    timeout: float = 30.0,
) -> dict[str, Any]:
    """POST JSON to a provider and return the decoded body.

    Raises ``AIError`` with a user-safe message and an appropriate status.
    """
    owns_client = client is None
    http_client = client or httpx.AsyncClient(timeout=timeout)
    try:
        response = await http_client.post(
            url, headers=headers, json=json_body, params=params
        )
    except httpx.HTTPError as exc:
        raise AIError("Could not reach the AI provider.", 502) from exc
    finally:
        if owns_client:
            await http_client.aclose()

    if response.status_code in (401, 403):
        raise AIError("The AI provider rejected the API key.", 502)
    if response.status_code == 429:
        raise AIError("AI rate limit reached. Try again later.", 429)
    if response.status_code >= 500:
        raise AIError("The AI provider is temporarily unavailable.", 502)
    if response.status_code != 200:
        raise AIError("The AI request failed.", 502)
    try:
        return response.json()
    except ValueError as exc:  # pragma: no cover - defensive
        raise AIError("Unexpected response from the AI provider.", 502) from exc
