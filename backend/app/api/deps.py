"""Shared FastAPI dependencies."""

from __future__ import annotations

from collections.abc import Generator

from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from sqlalchemy.orm import Session

from app.core.security import user_id_from_credentials
from app.db.session import get_engine, get_session

_bearer = HTTPBearer(auto_error=False)


def get_current_user_id(
    credentials: HTTPAuthorizationCredentials | None = Depends(_bearer),
) -> str:
    """Authenticated Supabase user id, or 401."""
    return user_id_from_credentials(credentials)


def get_db() -> Generator[Session, None, None]:
    """Database session, or 503 if the database is not configured."""
    if get_engine() is None:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Database is not configured.",
        )
    yield from get_session()
