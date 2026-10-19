"""Phase 8 hardening regression tests (fixes #1-#5).

Covers the rate-limit key, optional endpoint authentication, JWT issuer
pinning, bounded/typed uploads, and username validation/conflict handling.
No database, network, or model is required.
"""

from __future__ import annotations

import io
import time
import uuid

import jwt
import pytest
from fastapi import HTTPException
from fastapi.testclient import TestClient
from PIL import Image
from pydantic import ValidationError
from sqlalchemy.exc import IntegrityError
from starlette.requests import Request
from starlette.responses import PlainTextResponse

from app.api.deps import get_current_user_id, get_db
from app.api.routes import diagnosis as diagnosis_route
from app.core import rate_limit, security
from app.core.config import get_settings
from app.core.middleware import MaxBodySizeMiddleware
from app.main import app, create_app
from app.ml import labels, predictor
from app.ml.predictor import Prediction
from app.models.profile import Profile
from app.schemas.profile import ProfileUpdate

_ISSUER = "https://proj.supabase.co/auth/v1"


@pytest.fixture(autouse=True)
def _restore_settings_cache():
    yield
    get_settings.cache_clear()


def _token(secret: str, **claims: object) -> str:
    now = int(time.time())
    payload: dict[str, object] = {
        "sub": "user-123",
        "aud": "authenticated",
        "iat": now,
        "exp": now + 3600,
    }
    payload.update(claims)
    return jwt.encode(payload, secret, algorithm="HS256")


def _request(headers: dict[str, str] | None = None, client=("1.2.3.4", 1234)) -> Request:
    raw = [
        (key.lower().encode("latin-1"), value.encode("latin-1"))
        for key, value in (headers or {}).items()
    ]
    scope = {
        "type": "http",
        "http_version": "1.1",
        "method": "GET",
        "scheme": "http",
        "path": "/",
        "root_path": "",
        "headers": raw,
        "query_string": b"",
        "client": client,
        "server": ("testserver", 80),
    }
    return Request(scope)


def _make_app(monkeypatch, **env: object):
    for key, value in env.items():
        monkeypatch.setenv(key, str(value))
    get_settings.cache_clear()
    return create_app()


# --------------------------------------------------------------------------- #
# Fix #1: rate-limit key (authenticated user, trusted-proxy aware)
# --------------------------------------------------------------------------- #

def test_client_key_uses_user_when_token_valid(monkeypatch) -> None:
    monkeypatch.setenv("SUPABASE_JWT_SECRET", "test-secret")
    monkeypatch.setenv("SUPABASE_URL", "")
    monkeypatch.setenv("SUPABASE_JWT_ISSUER", "")
    get_settings.cache_clear()
    token = _token("test-secret")
    key_a = rate_limit.client_key(_request({"authorization": f"Bearer {token}"}))
    key_b = rate_limit.client_key(
        _request(
            {"authorization": f"Bearer {token}", "x-forwarded-for": "9.9.9.9"},
            client=("2.2.2.2", 2),
        )
    )
    assert key_a == key_b == "user:user-123"


def test_client_key_falls_back_to_ip_when_anonymous(monkeypatch) -> None:
    monkeypatch.setenv("SUPABASE_JWT_SECRET", "test-secret")
    get_settings.cache_clear()
    assert rate_limit.client_key(_request(client=("1.2.3.4", 1))) == "1.2.3.4"


def test_client_key_ignores_forwarded_for_from_untrusted_peer(monkeypatch) -> None:
    monkeypatch.setenv("TRUSTED_PROXY_IPS", "")
    monkeypatch.setenv("SUPABASE_JWT_SECRET", "test-secret")
    get_settings.cache_clear()
    key = rate_limit.client_key(
        _request({"x-forwarded-for": "9.9.9.9"}, client=("1.2.3.4", 1))
    )
    assert key == "1.2.3.4"


def test_client_key_ignores_forwarded_for_from_trusted_proxy(monkeypatch) -> None:
    # Superseded by Part D2: the app no longer parses X-Forwarded-For itself.
    # Uvicorn's --proxy-headers already resolves request.client from the trusted
    # proxy chain, so the forwarded header must not change the bucket.
    monkeypatch.setenv("TRUSTED_PROXY_IPS", "10.0.0.1")
    monkeypatch.setenv("SUPABASE_JWT_SECRET", "test-secret")
    get_settings.cache_clear()
    key = rate_limit.client_key(
        _request({"x-forwarded-for": "9.9.9.9"}, client=("10.0.0.1", 1))
    )
    assert key == "10.0.0.1"


def test_client_key_stable_across_different_forwarded_for(monkeypatch) -> None:
    monkeypatch.setenv("TRUSTED_PROXY_IPS", "*")
    monkeypatch.setenv("SUPABASE_JWT_SECRET", "test-secret")
    get_settings.cache_clear()
    key_a = rate_limit.client_key(_request({"x-forwarded-for": "1.1.1.1"}))
    key_b = rate_limit.client_key(_request({"x-forwarded-for": "2.2.2.2"}))
    assert key_a == key_b == "1.2.3.4"


def test_client_key_missing_client_address_is_unknown(monkeypatch) -> None:
    monkeypatch.setenv("SUPABASE_JWT_SECRET", "test-secret")
    get_settings.cache_clear()
    assert rate_limit.client_key(_request(client=None)) == "unknown"


def test_client_key_invalid_token_is_anonymous(monkeypatch) -> None:
    monkeypatch.setenv("SUPABASE_JWT_SECRET", "test-secret")
    get_settings.cache_clear()
    key = rate_limit.client_key(
        _request({"authorization": "Bearer not-a-real-token"}, client=("1.2.3.4", 1))
    )
    assert key == "1.2.3.4"


# --------------------------------------------------------------------------- #
# Fix #2: optional authentication on paid endpoints
# --------------------------------------------------------------------------- #

def test_ai_routes_require_auth_when_enabled(monkeypatch) -> None:
    app_ = _make_app(monkeypatch, REQUIRE_AUTH_FOR_AI="true", AI_PROVIDER="none")
    with TestClient(app_) as client:
        assert (
            client.post(
                "/api/chat", json={"messages": [{"role": "user", "content": "hi"}]}
            ).status_code
            == 401
        )
        assert (
            client.post(
                "/api/diagnose",
                files={"file": ("leaf.jpg", b"x", "image/jpeg")},
            ).status_code
            == 401
        )
        assert client.get("/api/weather", params={"q": "Pune"}).status_code == 401


def test_ai_routes_open_when_auth_not_required(monkeypatch) -> None:
    app_ = _make_app(monkeypatch, REQUIRE_AUTH_FOR_AI="false", AI_PROVIDER="none")
    with TestClient(app_) as client:
        response = client.post(
            "/api/chat", json={"messages": [{"role": "user", "content": "hi"}]}
        )
    # Anonymous access is allowed; the unconfigured provider yields 503, not 401.
    assert response.status_code == 503


def test_invalid_token_rejected_when_auth_required(monkeypatch) -> None:
    app_ = _make_app(
        monkeypatch,
        REQUIRE_AUTH_FOR_AI="true",
        SUPABASE_JWT_SECRET="test-secret",
    )
    with TestClient(app_) as client:
        response = client.post(
            "/api/chat",
            json={"messages": [{"role": "user", "content": "hi"}]},
            headers={"Authorization": "Bearer not-a-real-token"},
        )
    assert response.status_code == 401


# --------------------------------------------------------------------------- #
# Fix #4: JWT issuer pinning
# --------------------------------------------------------------------------- #

def test_issuer_enforced_when_configured(monkeypatch) -> None:
    monkeypatch.setenv("SUPABASE_JWT_SECRET", "test-secret")
    monkeypatch.setenv("SUPABASE_URL", "")
    monkeypatch.setenv("SUPABASE_JWT_ISSUER", _ISSUER)
    get_settings.cache_clear()
    good = _token("test-secret", iss=_ISSUER)
    bad = _token("test-secret", iss="https://evil.example/auth/v1")
    assert security.decode_supabase_token(good)["sub"] == "user-123"
    with pytest.raises(HTTPException) as excinfo:
        security.decode_supabase_token(bad)
    assert excinfo.value.status_code == 401


def test_issuer_derived_from_supabase_url(monkeypatch) -> None:
    monkeypatch.setenv("SUPABASE_JWT_SECRET", "test-secret")
    monkeypatch.setenv("SUPABASE_URL", "https://proj.supabase.co")
    monkeypatch.setenv("SUPABASE_JWT_ISSUER", "")
    get_settings.cache_clear()
    assert get_settings().expected_jwt_issuer == _ISSUER
    assert security.decode_supabase_token(_token("test-secret", iss=_ISSUER))[
        "sub"
    ] == "user-123"


def test_no_issuer_check_when_unset(monkeypatch) -> None:
    monkeypatch.setenv("SUPABASE_JWT_SECRET", "test-secret")
    monkeypatch.setenv("SUPABASE_URL", "")
    monkeypatch.setenv("SUPABASE_JWT_ISSUER", "")
    get_settings.cache_clear()
    assert get_settings().expected_jwt_issuer == ""
    # Token without an iss claim is accepted (legacy behaviour preserved).
    assert security.decode_supabase_token(_token("test-secret"))["sub"] == "user-123"


# --------------------------------------------------------------------------- #
# Fix #3: upload content-type gate + bounded chunked reading
# --------------------------------------------------------------------------- #

def test_content_type_helper() -> None:
    assert diagnosis_route._content_type_allowed("image/jpeg")
    assert diagnosis_route._content_type_allowed("image/png; charset=binary")
    assert diagnosis_route._content_type_allowed("application/octet-stream")
    assert diagnosis_route._content_type_allowed(None)
    assert not diagnosis_route._content_type_allowed("text/plain")
    assert not diagnosis_route._content_type_allowed("application/json")


def test_diagnose_rejects_unsupported_content_type(client: TestClient) -> None:
    response = client.post(
        "/api/diagnose",
        files={"file": ("leaf.txt", b"hello", "text/plain")},
    )
    assert response.status_code == 415


def test_diagnose_bounds_multichunk_upload(
    client: TestClient, monkeypatch: pytest.MonkeyPatch
) -> None:
    limit = diagnosis_route._READ_CHUNK_BYTES + 10
    monkeypatch.setattr(get_settings(), "max_photo_bytes", limit)
    payload = b"x" * (limit + 100)
    response = client.post(
        "/api/diagnose",
        files={"file": ("leaf.jpg", payload, "image/jpeg")},
    )
    assert response.status_code == 413


def test_diagnose_accepts_valid_image(
    client: TestClient, monkeypatch: pytest.MonkeyPatch
) -> None:
    def fake_classify(_data: bytes, top_k: int = 3) -> list[Prediction]:
        return [
            Prediction(
                class_index=0,
                label="Apple___healthy",
                confidence=0.9,
                crop_disease=labels.describe("Apple___healthy"),
            )
        ]

    monkeypatch.setattr(diagnosis_route, "classify", fake_classify)
    buffer = io.BytesIO()
    Image.new("RGB", (16, 16), (0, 128, 0)).save(buffer, format="JPEG")
    response = client.post(
        "/api/diagnose",
        files={"file": ("leaf.jpg", buffer.getvalue(), "image/jpeg")},
    )
    assert response.status_code == 200
    assert response.json()["crop"] == "Apple"


def test_diagnose_rejects_malformed_image(
    client: TestClient, monkeypatch: pytest.MonkeyPatch
) -> None:
    def fake_classify(data: bytes, top_k: int = 3) -> list[Prediction]:
        predictor._open_image(data)  # genuine decode; raises InvalidImage
        raise AssertionError("malformed image unexpectedly decoded")

    monkeypatch.setattr(diagnosis_route, "classify", fake_classify)
    response = client.post(
        "/api/diagnose",
        files={"file": ("leaf.jpg", b"not-an-image", "image/jpeg")},
    )
    assert response.status_code == 400


@pytest.mark.asyncio
async def test_max_body_size_middleware_missing_content_length_passes() -> None:
    async def inner(scope, receive, send):
        await PlainTextResponse("ok")(scope, receive, send)

    middleware = MaxBodySizeMiddleware(inner, max_bytes=10)
    messages: list[dict] = []

    async def receive():
        return {"type": "http.request", "body": b"x" * 100, "more_body": False}

    async def send(message):
        messages.append(message)

    scope = {
        "type": "http",
        "asgi": {"version": "3.0"},
        "http_version": "1.1",
        "method": "POST",
        "scheme": "http",
        "path": "/",
        "query_string": b"",
        "headers": [],
        "client": ("1.2.3.4", 1),
        "server": ("testserver", 80),
    }
    await middleware(scope, receive, send)
    status = next(m["status"] for m in messages if m["type"] == "http.response.start")
    assert status == 200


@pytest.mark.asyncio
async def test_max_body_size_middleware_rejects_declared_oversize() -> None:
    async def inner(scope, receive, send):
        await PlainTextResponse("ok")(scope, receive, send)

    middleware = MaxBodySizeMiddleware(inner, max_bytes=10)
    messages: list[dict] = []

    async def receive():
        return {"type": "http.request", "body": b"", "more_body": False}

    async def send(message):
        messages.append(message)

    scope = {
        "type": "http",
        "asgi": {"version": "3.0"},
        "http_version": "1.1",
        "method": "POST",
        "scheme": "http",
        "path": "/",
        "query_string": b"",
        "headers": [(b"content-length", b"100")],
        "client": ("1.2.3.4", 1),
        "server": ("testserver", 80),
    }
    await middleware(scope, receive, send)
    status = next(m["status"] for m in messages if m["type"] == "http.response.start")
    assert status == 413


# --------------------------------------------------------------------------- #
# Fix #5: username / language validation and conflict handling
# --------------------------------------------------------------------------- #

def test_profile_update_normalises_and_validates_username() -> None:
    assert ProfileUpdate(username="  good_name ").username == "good_name"
    assert ProfileUpdate(username="   ").username is None
    with pytest.raises(ValidationError):
        ProfileUpdate(username="ab")
    with pytest.raises(ValidationError):
        ProfileUpdate(username="bad name!")


def test_profile_update_validates_language() -> None:
    assert ProfileUpdate(preferred_language="hi").preferred_language == "hi"
    assert ProfileUpdate(preferred_language="  ").preferred_language is None
    with pytest.raises(ValidationError):
        ProfileUpdate(preferred_language="xx")


class _ConflictSession:
    """Session double whose commit raises a uniqueness violation."""

    def __init__(self, profile: Profile) -> None:
        self.profile = profile
        self.rolled_back = False

    def get(self, model, key):
        return self.profile

    def add(self, instance):
        self.profile = instance

    def commit(self):
        raise IntegrityError("INSERT", {}, Exception("duplicate key"))

    def rollback(self):
        self.rolled_back = True

    def refresh(self, instance):
        return None


def test_update_profile_username_conflict_returns_409(client: TestClient) -> None:
    user_id = uuid.uuid4()
    session = _ConflictSession(Profile(id=user_id))
    app.dependency_overrides[get_db] = lambda: session
    app.dependency_overrides[get_current_user_id] = lambda: str(user_id)
    try:
        response = client.put("/api/profile", json={"username": "taken"})
    finally:
        app.dependency_overrides.clear()

    assert response.status_code == 409
    assert session.rolled_back is True
