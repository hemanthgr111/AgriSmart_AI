"""Shared rate limiter (per authenticated user, else per client IP).

Protects paid/externally-backed endpoints (AI chat, diagnosis, weather) from
abuse so a single client cannot exhaust the free tier. Buckets are keyed on the
verified JWT subject when a bearer token is present, otherwise on the client IP
already resolved by the trusted proxy layer (Uvicorn's ``--proxy-headers``).
The limiter is created once at import; ``app.main`` registers its exception handler
and the routes apply per-route limits. Storage is in-memory by default (single
instance); set ``RATE_LIMIT_STORAGE_URI`` to a Redis URI when scaling out.
"""

from __future__ import annotations

from slowapi import Limiter
from starlette.requests import Request

from app.core.config import get_settings
from app.core.security import decode_supabase_token


def _subject_from_request(request: Request) -> str | None:
    """Return the JWT ``sub`` when a valid bearer token is present, else None."""
    header = request.headers.get("authorization")
    if not header:
        return None
    scheme, _, token = header.partition(" ")
    token = token.strip()
    if scheme.lower() != "bearer" or not token:
        return None
    try:
        payload = decode_supabase_token(token)
    except Exception:  # noqa: BLE001 - any decode failure means "anonymous"
        return None
    subject = payload.get("sub")
    return str(subject) if subject else None


def _client_ip(request: Request) -> str:
    """Return the client IP as already resolved by the trusted proxy layer.

    Uvicorn's ``--proxy-headers`` handling rewrites ``request.client`` from the
    trusted proxy chain, so this function must not parse ``X-Forwarded-For``
    itself: doing so would reintroduce a second, independently spoofable trust
    path. Fall back deterministically when the address is unavailable.
    """
    peer = request.client.host if request.client else None
    return peer or "unknown"


def client_key(request: Request) -> str:
    """Rate-limit bucket: authenticated user when possible, else client IP.

    Keying on the verified user id means a caller cannot evade per-user limits
    by spoofing a forwarded-for header, even behind a trusted proxy.
    """
    subject = _subject_from_request(request)
    if subject:
        return f"user:{subject}"
    return _client_ip(request)


_settings = get_settings()

limiter = Limiter(
    key_func=client_key,
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
