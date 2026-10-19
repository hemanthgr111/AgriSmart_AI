"""Weather endpoints (WeatherAPI.com proxy)."""

from __future__ import annotations

from fastapi import APIRouter, Depends, HTTPException, Request

from app.api.deps import require_ai_access
from app.core.rate_limit import WEATHER_RATE_LIMIT, limiter
from app.schemas.weather import WeatherResponse
from app.services.weather_client import WeatherError, fetch_weather

router = APIRouter(prefix="/weather", tags=["weather"])


@router.get("", response_model=WeatherResponse)
@limiter.limit(WEATHER_RATE_LIMIT)
async def get_weather(
    request: Request,
    q: str | None = None,
    lat: float | None = None,
    lon: float | None = None,
    _auth: None = Depends(require_ai_access),
) -> WeatherResponse:
    """Return current weather and a short forecast for a location.

    Provide either `q` (a location name) or both `lat` and `lon`. Results are
    cached briefly on the server. The weather API key stays server-side.
    """
    try:
        return await fetch_weather(q=q, lat=lat, lon=lon)
    except WeatherError as error:
        raise HTTPException(status_code=error.status_code, detail=error.message)
