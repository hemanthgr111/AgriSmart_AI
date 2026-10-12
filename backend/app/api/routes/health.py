"""Health and readiness endpoints."""

from datetime import UTC, datetime

from fastapi import APIRouter

from app import __version__
from app.core.config import get_settings
from app.db.session import check_database
from app.schemas.health import HealthResponse

router = APIRouter(tags=["health"])


@router.get("/health", response_model=HealthResponse)
def health() -> HealthResponse:
    """Liveness/readiness probe used by Render and load balancers.

    Always returns 200 while the process is alive. The `database` field
    reports connectivity so cold-start / credential problems are visible.
    """
    settings = get_settings()
    db_status = "connected" if check_database() else "unavailable"
    return HealthResponse(
        status="ok",
        app=settings.app_name,
        version=__version__,
        environment=settings.environment,
        database=db_status,
        timestamp=datetime.now(UTC),
    )
