"""WeatherAPI.com client with a small in-process TTL cache.

The API key is read from the backend environment and is never exposed to
clients. No weather values are ever fabricated: if the upstream call fails,
an error is raised and the client is expected to surface it.
"""

from __future__ import annotations

import time
from datetime import UTC, datetime
from typing import Any

import httpx

from app.core.config import get_settings
from app.schemas.weather import WeatherResponse


class WeatherError(Exception):
    """Raised for any weather-service failure. Carries an HTTP status."""

    def __init__(self, message: str, status_code: int = 502) -> None:
        super().__init__(message)
        self.message = message
        self.status_code = status_code


class _TTLCache:
    def __init__(self) -> None:
        self._store: dict[str, tuple[float, Any]] = {}

    def get(self, key: str) -> Any | None:
        entry = self._store.get(key)
        if entry is None:
            return None
        expires_at, value = entry
        if expires_at < time.monotonic():
            self._store.pop(key, None)
            return None
        return value

    def set(self, key: str, value: Any, ttl_seconds: int) -> None:
        self._store[key] = (time.monotonic() + ttl_seconds, value)

    def clear(self) -> None:
        self._store.clear()


cache = _TTLCache()


def _cache_key(q: str | None, lat: float | None, lon: float | None) -> str:
    if q:
        return f"q:{q.strip().lower()}"
    return f"c:{lat:.3f},{lon:.3f}"


def normalize_payload(data: dict[str, Any]) -> dict[str, Any]:
    """Map a WeatherAPI forecast.json payload into our response shape."""
    try:
        location = data["location"]
        current = data["current"]
        days = data["forecast"]["forecastday"]
    except (KeyError, TypeError) as exc:
        raise WeatherError("Unexpected response from weather service.", 502) from exc

    forecast: list[dict[str, Any]] = []
    for day in days:
        day_data = day.get("day", {})
        condition = day_data.get("condition", {})
        forecast.append(
            {
                "date": day.get("date"),
                "max_temp_c": day_data.get("maxtemp_c"),
                "min_temp_c": day_data.get("mintemp_c"),
                "avg_humidity": day_data.get("avghumidity"),
                "chance_of_rain": day_data.get("daily_chance_of_rain"),
                "condition": condition.get("text"),
                "icon": condition.get("icon"),
            }
        )

    current_condition = current.get("condition", {})
    return {
        "location": {
            "name": location.get("name"),
            "region": location.get("region"),
            "country": location.get("country"),
            "lat": location.get("lat"),
            "lon": location.get("lon"),
            "localtime": location.get("localtime"),
        },
        "current": {
            "temp_c": current.get("temp_c"),
            "feelslike_c": current.get("feelslike_c"),
            "humidity": current.get("humidity"),
            "wind_kph": current.get("wind_kph"),
            "wind_dir": current.get("wind_dir"),
            "precip_mm": current.get("precip_mm"),
            "condition": current_condition.get("text"),
            "icon": current_condition.get("icon"),
            "is_day": current.get("is_day"),
        },
        "forecast": forecast,
        "updated_at": datetime.now(UTC).isoformat(),
    }


def _validate_target(
    q: str | None, lat: float | None, lon: float | None
) -> str:
    if q and q.strip():
        return q.strip()
    if lat is not None and lon is not None:
        return f"{lat},{lon}"
    raise WeatherError(
        "Provide a location name or both latitude and longitude.", 400
    )


async def fetch_weather(
    *,
    q: str | None = None,
    lat: float | None = None,
    lon: float | None = None,
    client: httpx.AsyncClient | None = None,
) -> WeatherResponse:
    settings = get_settings()
    if not settings.weather_api_key:
        raise WeatherError("Weather service is not configured.", 503)

    target = _validate_target(q, lat, lon)
    key = _cache_key(q, lat, lon)

    cached = cache.get(key)
    if cached is not None:
        return WeatherResponse.model_validate(cached)

    params = {
        "key": settings.weather_api_key,
        "q": target,
        "days": 3,
        "aqi": "no",
        "alerts": "no",
    }
    url = f"{settings.weather_api_base_url}/forecast.json"

    owns_client = client is None
    http_client = client or httpx.AsyncClient(timeout=10.0)
    try:
        response = await http_client.get(url, params=params)
    except httpx.HTTPError as exc:
        raise WeatherError("Could not reach the weather service.", 502) from exc
    finally:
        if owns_client:
            await http_client.aclose()

    if response.status_code == 400:
        raise WeatherError("Location not found. Try another.", 400)
    if response.status_code in (401, 403):
        raise WeatherError("Weather service rejected the API key.", 502)
    if response.status_code == 429:
        raise WeatherError("Weather rate limit reached. Try again later.", 429)
    if response.status_code >= 500:
        raise WeatherError("Weather service is temporarily unavailable.", 502)
    if response.status_code != 200:
        raise WeatherError("Weather request failed.", 502)

    normalized = normalize_payload(response.json())
    cache.set(key, normalized, settings.weather_cache_ttl_seconds)
    return WeatherResponse.model_validate(normalized)
