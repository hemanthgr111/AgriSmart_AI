"""Supabase JWT verification for protected endpoints.

Supabase signs access tokens with the project's JWT secret (HS256, legacy) or
an asymmetric key (ES256/RS256, newer projects). This module verifies HS256
tokens using SUPABASE_JWT_SECRET. If your project uses asymmetric signing,
extend `decode_supabase_token` to fetch and use the project's JWKS.
"""

from __future__ import annotations

import logging

import jwt
from fastapi import HTTPException, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer

from app.core.config import get_settings

logger = logging.getLogger(__name__)

bearer_scheme = HTTPBearer(auto_error=False)


def decode_supabase_token(token: str) -> dict:
    """Decode and validate a Supabase access token. Raises HTTPException on error."""
    settings = get_settings()
    if not settings.supabase_jwt_secret:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Authentication is not configured on the server.",
        )
    try:
        return jwt.decode(
            token,
            settings.supabase_jwt_secret,
            algorithms=["HS256"],
            audience="authenticated",
        )
    except jwt.ExpiredSignatureError as exc:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Session expired. Please sign in again.",
        ) from exc
    except jwt.PyJWTError as exc:
        logger.info("Rejected invalid token: %s", type(exc).__name__)
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid authentication token.",
        ) from exc


def user_id_from_credentials(
    credentials: HTTPAuthorizationCredentials | None,
) -> str:
    """Return the authenticated user's id (JWT `sub`) or raise 401."""
    if credentials is None or not credentials.credentials:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Missing authentication token.",
            headers={"WWW-Authenticate": "Bearer"},
        )
    payload = decode_supabase_token(credentials.credentials)
    subject = payload.get("sub")
    if not subject:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid authentication token.",
        )
    return str(subject)
