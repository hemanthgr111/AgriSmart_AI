"""Shared rate limiter (per client IP).

Protects paid/externally-backed endpoints (AI chat, diagnosis, weather) from
abuse so a single client cannot exhaust the free tier. The limiter is created
once at import; ``app.main`` registers its exception handler and the routes
apply per-route limits. Storage is in-memory by default (single instance); set
``RATE_LIMIT_STORAGE_URI`` to a Redis URI when running multiple instances.
"""

from __future__ import annotations

from slowapi import Limiter
from slowapi.util import get_remote_address

from app.core.config import get_settings

_settings = get_settings()

limiter = Limiter(
    key_func=get_remote_address,
    default_limits=[],
    storage_uri=_settings.rate_limit_storage_uri,
    enabled=_settings.rate_limit_enabled,
)

# Rate limit strings, captured at import for use in route decorators.
CHAT_RATE_LIMIT = _settings.rate_limit_chat
DIAGNOSE_RATE_LIMIT = _settings.rate_limit_diagnose
WEATHER_RATE_LIMIT = _settings.rate_limit_weather

__all__ = [
    "CHAT_RATE_LIMIT",
    "DIAGNOSE_RATE_LIMIT",
    "WEATHER_RATE_LIMIT",
    "limiter",
]
