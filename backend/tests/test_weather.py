"""Weather endpoint and normalizer tests (no live API calls)."""

from __future__ import annotations

import httpx
import pytest

from app.core.config import get_settings
from app.services.weather_client import (
    WeatherError,
    cache,
    fetch_weather,
    normalize_payload,
)


def teardown_function() -> None:
    get_settings.cache_clear()
    cache.clear()


def _mock_client(handler) -> httpx.AsyncClient:
    return httpx.AsyncClient(transport=httpx.MockTransport(handler))

_SAMPLE = {
    "location": {
        "name": "Mumbai",
        "region": "Maharashtra",
        "country": "India",
        "lat": 19.07,
        "lon": 72.87,
        "localtime": "2026-01-01 10:00",
    },
    "current": {
        "temp_c": 30.0,
        "feelslike_c": 33.0,
        "humidity": 60,
        "wind_kph": 12.0,
        "wind_dir": "W",
        "precip_mm": 0.0,
        "condition": {"text": "Sunny", "icon": "//cdn/sun.png"},
        "is_day": 1,
    },
    "forecast": {
        "forecastday": [
            {
                "date": "2026-01-01",
                "day": {
                    "maxtemp_c": 32.0,
                    "mintemp_c": 20.0,
                    "avghumidity": 55,
                    "daily_chance_of_rain": 10,
                    "condition": {"text": "Sunny", "icon": "//cdn/sun.png"},
                },
            }
        ]
    },
}


def test_normalize_payload_maps_fields():
    result = normalize_payload(_SAMPLE)
    assert result["location"]["name"] == "Mumbai"
    assert result["current"]["temp_c"] == 30.0
    assert result["current"]["condition"] == "Sunny"
    assert result["current"]["humidity"] == 60
    assert len(result["forecast"]) == 1
    assert result["forecast"][0]["chance_of_rain"] == 10
    assert "updated_at" in result


def test_normalize_payload_rejects_bad_input():
    try:
        normalize_payload({"unexpected": True})
    except WeatherError as error:
        assert error.status_code == 502
    else:  # pragma: no cover
        raise AssertionError("expected WeatherError")


def test_weather_not_configured_returns_503(client, monkeypatch):
    monkeypatch.setenv("WEATHER_API_KEY", "")
    get_settings.cache_clear()
    cache.clear()
    response = client.get("/api/weather", params={"q": "Pune"})
    assert response.status_code == 503
    get_settings.cache_clear()


def test_weather_missing_params_returns_400(client, monkeypatch):
    monkeypatch.setenv("WEATHER_API_KEY", "test-key")
    get_settings.cache_clear()
    cache.clear()
    response = client.get("/api/weather")
    assert response.status_code == 400
    get_settings.cache_clear()


def _configure(monkeypatch) -> None:
    monkeypatch.setenv("WEATHER_API_KEY", "test-key")
    get_settings.cache_clear()
    cache.clear()


@pytest.mark.asyncio
async def test_fetch_weather_success_and_cache(monkeypatch):
    _configure(monkeypatch)
    calls = {"n": 0}

    def handler(request: httpx.Request) -> httpx.Response:
        calls["n"] += 1
        return httpx.Response(200, json=_SAMPLE)

    async with _mock_client(handler) as client:
        first = await fetch_weather(q="Mumbai", client=client)
        # Second call for the same location must be served from cache.
        second = await fetch_weather(q="Mumbai", client=client)

    assert first.location.name == "Mumbai"
    assert first.current.temp_c == 30.0
    assert second.current.condition == "Sunny"
    assert calls["n"] == 1


@pytest.mark.asyncio
async def test_fetch_weather_by_coordinates(monkeypatch):
    _configure(monkeypatch)
    seen: dict[str, str] = {}

    def handler(request: httpx.Request) -> httpx.Response:
        seen["q"] = request.url.params.get("q", "")
        return httpx.Response(200, json=_SAMPLE)

    async with _mock_client(handler) as client:
        await fetch_weather(lat=19.07, lon=72.87, client=client)

    assert seen["q"] == "19.07,72.87"


@pytest.mark.asyncio
async def test_fetch_weather_timeout_raises_502(monkeypatch):
    _configure(monkeypatch)

    def handler(request: httpx.Request) -> httpx.Response:
        raise httpx.ConnectTimeout("timed out")

    async with _mock_client(handler) as client:
        with pytest.raises(WeatherError) as excinfo:
            await fetch_weather(q="Pune", client=client)
    assert excinfo.value.status_code == 502


@pytest.mark.asyncio
@pytest.mark.parametrize(
    ("status", "expected"),
    [(400, 400), (401, 502), (403, 502), (429, 429), (500, 502), (503, 502)],
)
async def test_fetch_weather_maps_upstream_status(monkeypatch, status, expected):
    _configure(monkeypatch)

    def handler(request: httpx.Request) -> httpx.Response:
        return httpx.Response(status, json={})

    async with _mock_client(handler) as client:
        with pytest.raises(WeatherError) as excinfo:
            await fetch_weather(q="Delhi", client=client)
    assert excinfo.value.status_code == expected


def test_weather_error_maps_to_http_status(client, monkeypatch):
    import app.api.routes.weather as weather_route

    async def boom(**kwargs):
        raise WeatherError("Weather service is temporarily unavailable.", 502)

    monkeypatch.setattr(weather_route, "fetch_weather", boom)
    response = client.get("/api/weather", params={"q": "Goa"})
    assert response.status_code == 502
