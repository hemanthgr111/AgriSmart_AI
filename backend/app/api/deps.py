"""Shared FastAPI dependencies."""

from __future__ import annotations

from collections.abc import Generator

from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from sqlalchemy.orm import Session

from app.core.config import get_settings
from app.core.security import user_id_from_credentials
from app.db.session import get_engine, get_session

_bearer = HTTPBearer(auto_error=False)


def get_current_user_id(
    credentials: HTTPAuthorizationCredentials | None = Depends(_bearer),
) -> str:
    """Authenticated Supabase user id, or 401."""
    return user_id_from_credentials(credentials)


def get_optional_user_id(
    credentials: HTTPAuthorizationCredentials | None = Depends(_bearer),
) -> str | None:
    """Authenticated user id when a valid token is supplied, else None.

    A token that is present but invalid is rejected (401) rather than silently
    downgraded to an anonymous caller.
    """
    if credentials is None or not credentials.credentials:
        return None
    return user_id_from_credentials(credentials)


def require_ai_access(
    user_id: str | None = Depends(get_optional_user_id),
) -> None:
    """Gate paid endpoints when ``REQUIRE_AUTH_FOR_AI`` is enabled.

    Anonymous callers are rejected only when the operator opts in; by default
    guest access is preserved and rate limiting is the primary guard.
    """
    if get_settings().require_auth_for_ai and user_id is None:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Authentication is required for this endpoint.",
            headers={"WWW-Authenticate": "Bearer"},
        )


def get_db() -> Generator[Session, None, None]:
    """Database session, or 503 if the database is not configured."""
    if get_engine() is None:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Database is not configured.",
        )
    yield from get_session()
