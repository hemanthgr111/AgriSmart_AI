"""Integration tests for Uvicorn's ProxyHeadersMiddleware trust behavior.

These exercise Uvicorn's ``ProxyHeadersMiddleware`` in-process via Starlette's
``TestClient``. They document the *middleware's* behavior only; they do NOT and
cannot establish how Render's live edge proxy populates ``X-Forwarded-For``.

The peer seen by the middleware under ``TestClient`` is ``"testclient"``.
"""

from __future__ import annotations

from starlette.applications import Starlette
from starlette.requests import Request
from starlette.responses import JSONResponse
from starlette.routing import Route
from starlette.testclient import TestClient
from uvicorn.middleware.proxy_headers import ProxyHeadersMiddleware

from app.core.rate_limit import client_key


def _build_app() -> Starlette:
    async def whoami(request: Request) -> JSONResponse:
        return JSONResponse(
            {
                "client": request.client.host if request.client else None,
                "key": client_key(request),
            }
        )

    return Starlette(routes=[Route("/whoami", whoami)])


def _client(trusted_hosts: str | list[str]) -> TestClient:
    return TestClient(ProxyHeadersMiddleware(_build_app(), trusted_hosts=trusted_hosts))


def test_wildcard_trust_uses_leftmost_forwarded_for() -> None:
    # "*" trusts every peer; Uvicorn adopts the leftmost X-Forwarded-For entry.
    with _client("*") as client:
        response = client.get(
            "/whoami", headers={"x-forwarded-for": "203.0.113.9, 198.51.100.7"}
        )
    assert response.status_code == 200
    assert response.json()["client"] == "203.0.113.9"
    # The anonymous rate-limit key follows the middleware-resolved client.
    assert response.json()["key"] == "203.0.113.9"


def test_wildcard_trust_without_forwarded_for_uses_socket_peer() -> None:
    with _client("*") as client:
        response = client.get("/whoami")
    assert response.json()["client"] == "testclient"
    assert response.json()["key"] == "testclient"


def test_trusted_host_ignores_forwarded_for_from_non_matching_peer() -> None:
    # The configured trusted host ("10.0.0.1") does not match the peer, so the
    # forwarded header is ignored and the socket peer is used.
    with _client("10.0.0.1") as client:
        response = client.get("/whoami", headers={"x-forwarded-for": "203.0.113.9"})
    assert response.json()["client"] == "testclient"
    assert response.json()["key"] == "testclient"


def test_trusted_host_with_matching_peer_selects_rightmost_untrusted() -> None:
    # With a specific trusted host (not "*"), Uvicorn scans X-Forwarded-For from
    # the right and adopts the first entry that is not itself a trusted host,
    # rather than the leftmost entry.
    with _client("testclient") as client:
        response = client.get(
            "/whoami", headers={"x-forwarded-for": "203.0.113.9, 198.51.100.7"}
        )
    assert response.json()["client"] == "198.51.100.7"
    assert response.json()["key"] == "198.51.100.7"
