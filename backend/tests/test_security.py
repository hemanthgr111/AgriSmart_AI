"""Security hardening and cost-control tests (Phase 8)."""

from __future__ import annotations

import pytest
from fastapi.testclient import TestClient

from app.core.config import get_settings
from app.core.rate_limit import CHAT_RATE_LIMIT, limiter
from app.main import create_app


@pytest.fixture()
def make_app(monkeypatch):
    """Build a fresh app with the given environment overrides."""

    def _make(**env: object):
        for key, value in env.items():
            monkeypatch.setenv(key, str(value))
        get_settings.cache_clear()
        return create_app()

    yield _make
    get_settings.cache_clear()


def test_security_headers_present(client) -> None:
    response = client.get("/api/health")
    assert response.status_code == 200
    assert response.headers["x-content-type-options"] == "nosniff"
    assert response.headers["x-frame-options"] == "DENY"
    assert response.headers["referrer-policy"] == "no-referrer"


def test_no_hsts_outside_production(client) -> None:
    response = client.get("/api/health")
    assert "strict-transport-security" not in response.headers


def test_hsts_added_in_production(make_app) -> None:
    app = make_app(ENVIRONMENT="production")
    with TestClient(app) as test_client:
        response = test_client.get("/api/health")
    assert "strict-transport-security" in response.headers


def test_gzip_compresses_large_response(make_app) -> None:
    app = make_app(GZIP_MIN_SIZE=100)
    with TestClient(app) as test_client:
        # Ask for gzip and inspect the raw (undecoded) response.
        raw = test_client.get(
            "/openapi.json",
            headers={"Accept-Encoding": "gzip"},
        )
    assert raw.status_code == 200
    assert raw.headers.get("content-encoding") == "gzip"


def test_large_request_body_rejected(make_app) -> None:
    app = make_app(MAX_REQUEST_BYTES=100, AI_PROVIDER="none")
    with TestClient(app) as test_client:
        response = test_client.post(
            "/api/chat",
            json={"messages": [{"role": "user", "content": "x" * 500}]},
        )
    assert response.status_code == 413


def test_docs_disabled_when_configured(make_app) -> None:
    app = make_app(ENABLE_API_DOCS="false")
    with TestClient(app) as test_client:
        assert test_client.get("/docs").status_code == 404
        assert test_client.get("/openapi.json").status_code == 404


def test_cors_wildcard_omits_credentials(client) -> None:
    response = client.get("/api/health", headers={"Origin": "https://example.com"})
    assert response.headers.get("access-control-allow-origin") == "*"
    assert "access-control-allow-credentials" not in response.headers


def test_rate_limit_returns_429(make_app) -> None:
    limiter.enabled = True
    try:
        limiter.reset()
        app = make_app(AI_PROVIDER="none")
        limit = int(CHAT_RATE_LIMIT.split("/")[0])
        with TestClient(app) as test_client:
            codes = [
                test_client.post(
                    "/api/chat",
                    json={"messages": [{"role": "user", "content": "hi"}]},
                ).status_code
                for _ in range(limit + 1)
            ]
        assert 429 in codes
    finally:
        limiter.enabled = False
        limiter.reset()
