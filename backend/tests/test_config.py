"""Configuration parsing and derived-property tests."""

from __future__ import annotations

from app.core.config import Settings


def _settings(**kwargs) -> Settings:
    # ``_env_file=None`` keeps these tests hermetic (ignores any local .env).
    return Settings(_env_file=None, **kwargs)


def test_defaults_are_cost_conscious() -> None:
    settings = _settings()
    assert settings.ai_provider == "none"
    assert settings.ai_max_output_tokens == 800
    # conftest forces RATE_LIMIT_ENABLED=false for the suite, so read the
    # declared default directly to assert the production default.
    assert Settings.model_fields["rate_limit_enabled"].default is True
    assert settings.rate_limit_chat == "20/minute"
    assert settings.rate_limit_diagnose == "30/minute"
    assert settings.rate_limit_weather == "60/minute"
    assert settings.max_request_bytes > 0


def test_cors_origin_list_parsing() -> None:
    settings = _settings(cors_origins="https://a.com, https://b.com ,")
    assert settings.cors_origin_list == ["https://a.com", "https://b.com"]


def test_allowed_host_list_defaults_to_wildcard() -> None:
    assert _settings(allowed_hosts="").allowed_host_list == ["*"]
    assert _settings(allowed_hosts="api.example.com").allowed_host_list == [
        "api.example.com"
    ]


def test_is_production() -> None:
    assert _settings(environment="production").is_production is True
    assert _settings(environment="PROD").is_production is True
    assert _settings(environment="development").is_production is False
    assert _settings(environment="staging").is_production is False
