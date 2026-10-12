"""Database engine and session management (Supabase PostgreSQL).

The engine is created lazily so that the application can start (and serve
`/api/health`) even when no database driver or connection string is
configured yet. This keeps local development and CI usable without secrets.
"""

from __future__ import annotations

import logging

from sqlalchemy import create_engine, text
from sqlalchemy.engine import Engine
from sqlalchemy.orm import DeclarativeBase, Session, sessionmaker

from app.core.config import get_settings

logger = logging.getLogger(__name__)

_engine: Engine | None = None
_SessionLocal: sessionmaker | None = None


class Base(DeclarativeBase):
    """Declarative base for all ORM models."""


def get_engine() -> Engine | None:
    """Create (once) and return the SQLAlchemy engine, or None if unconfigured."""
    global _engine, _SessionLocal
    if _engine is not None:
        return _engine

    settings = get_settings()
    if not settings.database_url:
        logger.warning("DATABASE_URL is not set; database features are disabled.")
        return None

    try:
        _engine = create_engine(
            settings.database_url,
            pool_pre_ping=True,
            pool_size=5,
            max_overflow=5,
            pool_recycle=1800,
        )
        _SessionLocal = sessionmaker(bind=_engine, autoflush=False, autocommit=False)
    except Exception:  # pragma: no cover - driver/config errors
        logger.exception("Failed to create database engine; database features disabled.")
        _engine = None
        _SessionLocal = None

    return _engine


def get_session() -> Session:
    """FastAPI dependency yielding a database session."""
    if _SessionLocal is None:
        get_engine()
    if _SessionLocal is None:
        raise RuntimeError("Database is not configured.")
    session = _SessionLocal()
    try:
        yield session
    finally:
        session.close()


def check_database() -> bool:
    """Return True if a simple query succeeds, False otherwise."""
    engine = get_engine()
    if engine is None:
        return False
    try:
        with engine.connect() as conn:
            conn.execute(text("SELECT 1"))
        return True
    except Exception:  # pragma: no cover - network/credential errors
        logger.exception("Database health check failed.")
        return False
