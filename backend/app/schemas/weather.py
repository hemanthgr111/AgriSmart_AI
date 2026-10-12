"""Weather response schemas."""

from __future__ import annotations

from datetime import datetime

from pydantic import BaseModel


class WeatherLocation(BaseModel):
    name: str | None = None
    region: str | None = None
    country: str | None = None
    lat: float | None = None
    lon: float | None = None
    localtime: str | None = None


class WeatherCurrent(BaseModel):
    temp_c: float | None = None
    feelslike_c: float | None = None
    humidity: int | None = None
    wind_kph: float | None = None
    wind_dir: str | None = None
    precip_mm: float | None = None
    condition: str | None = None
    icon: str | None = None
    is_day: int | None = None


class WeatherDay(BaseModel):
    date: str | None = None
    max_temp_c: float | None = None
    min_temp_c: float | None = None
    avg_humidity: int | None = None
    chance_of_rain: int | None = None
    condition: str | None = None
    icon: str | None = None


class WeatherResponse(BaseModel):
    location: WeatherLocation
    current: WeatherCurrent
    forecast: list[WeatherDay]
    updated_at: datetime
