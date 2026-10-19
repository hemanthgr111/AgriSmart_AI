"""Asymmetric (JWKS) JWT verification tests.

Covers acceptance of ES256/RS256 Supabase access tokens via the project JWKS,
the legacy HS256 shared-secret fallback, issuer/audience enforcement, and the
error mapping for unconfigured JWKS or unreachable key sets.

The JWKS client is faked, so no database, network, or live service is contacted.
"""

from __future__ import annotations

import json
import time

import jwt
import pytest
from cryptography.hazmat.primitives.asymmetric import ec, rsa
from fastapi import HTTPException

from app.core import security
from app.core.config import get_settings

_ISSUER = "https://proj.supabase.co/auth/v1"


@pytest.fixture(autouse=True)
def _restore_settings_cache():
    get_settings.cache_clear()
    yield
    get_settings.cache_clear()


class _FakeSigningKey:
    def __init__(self, key: object) -> None:
        self.key = key


class _FakeJwksClient:
    def __init__(self, key: object) -> None:
        self._key = key

    def get_signing_key_from_jwt(self, token: str) -> _FakeSigningKey:
        return _FakeSigningKey(self._key)


class _UnknownKeyJwksClient:
    def get_signing_key_from_jwt(self, token: str) -> _FakeSigningKey:
        raise jwt.PyJWKClientError("Unable to find a signing key")


class _UnreachableJwksClient:
    def get_signing_key_from_jwt(self, token: str) -> _FakeSigningKey:
        raise jwt.PyJWKClientConnectionError("could not reach JWKS")


class _EmptyKeySetJwksClient:
    def get_signing_key_from_jwt(self, token: str) -> _FakeSigningKey:
        raise jwt.PyJWKSetError("The JWK Set did not contain any usable keys")


class _MalformedJsonJwksClient:
    def get_signing_key_from_jwt(self, token: str) -> _FakeSigningKey:
        raise json.JSONDecodeError("Expecting value", "<html>not json</html>", 0)


def _claims(**extra: object) -> dict[str, object]:
    now = int(time.time())
    payload: dict[str, object] = {
        "sub": "user-123",
        "aud": "authenticated",
        "iat": now,
        "exp": now + 3600,
    }
    payload.update(extra)
    return payload


def _es256() -> tuple[object, object]:
    private = ec.generate_private_key(ec.SECP256R1())
    return private, private.public_key()


def _rs256() -> tuple[object, object]:
    private = rsa.generate_private_key(public_exponent=65537, key_size=2048)
    return private, private.public_key()


def _use_jwks(monkeypatch: pytest.MonkeyPatch, key: object) -> None:
    monkeypatch.setattr(security, "_get_jwks_client", lambda url: _FakeJwksClient(key))


# --------------------------------------------------------------------------- #
# Asymmetric acceptance
# --------------------------------------------------------------------------- #


def test_es256_token_verified_via_jwks(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setenv("SUPABASE_URL", "https://proj.supabase.co")
    monkeypatch.setenv("SUPABASE_JWT_SECRET", "")
    get_settings.cache_clear()
    private, public = _es256()
    _use_jwks(monkeypatch, public)
    token = jwt.encode(_claims(iss=_ISSUER), private, algorithm="ES256")
    assert security.decode_supabase_token(token)["sub"] == "user-123"


def test_rs256_token_verified_via_jwks(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setenv("SUPABASE_URL", "https://proj.supabase.co")
    monkeypatch.setenv("SUPABASE_JWT_SECRET", "")
    get_settings.cache_clear()
    private, public = _rs256()
    _use_jwks(monkeypatch, public)
    token = jwt.encode(_claims(iss=_ISSUER), private, algorithm="RS256")
    assert security.decode_supabase_token(token)["sub"] == "user-123"


def test_explicit_jwks_url_overrides_derived(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    monkeypatch.setenv("SUPABASE_URL", "https://proj.supabase.co")
    monkeypatch.setenv("SUPABASE_JWKS_URL", "https://custom.test/jwks.json")
    get_settings.cache_clear()
    assert get_settings().expected_jwks_url == "https://custom.test/jwks.json"


def test_jwks_url_derived_from_supabase_url(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setenv("SUPABASE_URL", "https://proj.supabase.co")
    monkeypatch.setenv("SUPABASE_JWKS_URL", "")
    get_settings.cache_clear()
    assert (
        get_settings().expected_jwks_url
        == "https://proj.supabase.co/auth/v1/.well-known/jwks.json"
    )


# --------------------------------------------------------------------------- #
# Legacy HS256 fallback
# --------------------------------------------------------------------------- #


def test_hs256_fallback_still_works(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setenv("SUPABASE_JWT_SECRET", "test-secret")
    monkeypatch.setenv("SUPABASE_URL", "")
    get_settings.cache_clear()
    token = jwt.encode(_claims(), "test-secret", algorithm="HS256")
    assert security.decode_supabase_token(token)["sub"] == "user-123"


def test_hs256_rejected_with_wrong_secret(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setenv("SUPABASE_JWT_SECRET", "test-secret")
    monkeypatch.setenv("SUPABASE_URL", "")
    get_settings.cache_clear()
    token = jwt.encode(_claims(), "other-secret", algorithm="HS256")
    with pytest.raises(HTTPException) as excinfo:
        security.decode_supabase_token(token)
    assert excinfo.value.status_code == 401


def test_legacy_hs256_allowed_by_default(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.delenv("ALLOW_LEGACY_HS256", raising=False)
    monkeypatch.setenv("SUPABASE_JWT_SECRET", "test-secret")
    monkeypatch.setenv("SUPABASE_URL", "")
    get_settings.cache_clear()
    assert get_settings().allow_legacy_hs256 is True
    token = jwt.encode(_claims(), "test-secret", algorithm="HS256")
    assert security.decode_supabase_token(token)["sub"] == "user-123"


def test_hs256_rejected_when_legacy_disabled(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setenv("ALLOW_LEGACY_HS256", "false")
    monkeypatch.setenv("SUPABASE_JWT_SECRET", "test-secret")
    monkeypatch.setenv("SUPABASE_URL", "")
    get_settings.cache_clear()
    # A valid HS256 token signed with the configured secret must still be
    # rejected when legacy HS256 is disabled.
    token = jwt.encode(_claims(), "test-secret", algorithm="HS256")
    with pytest.raises(HTTPException) as excinfo:
        security.decode_supabase_token(token)
    assert excinfo.value.status_code == 401


def test_es256_verified_when_legacy_disabled(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setenv("ALLOW_LEGACY_HS256", "false")
    monkeypatch.setenv("SUPABASE_URL", "https://proj.supabase.co")
    monkeypatch.setenv("SUPABASE_JWT_SECRET", "")
    get_settings.cache_clear()
    private, public = _es256()
    _use_jwks(monkeypatch, public)
    token = jwt.encode(_claims(iss=_ISSUER), private, algorithm="ES256")
    assert security.decode_supabase_token(token)["sub"] == "user-123"


# --------------------------------------------------------------------------- #
# Claim enforcement
# --------------------------------------------------------------------------- #


def test_es256_issuer_pinning(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setenv("SUPABASE_URL", "https://proj.supabase.co")
    monkeypatch.setenv("SUPABASE_JWT_SECRET", "")
    get_settings.cache_clear()
    private, public = _es256()
    _use_jwks(monkeypatch, public)
    good = jwt.encode(_claims(iss=_ISSUER), private, algorithm="ES256")
    bad = jwt.encode(
        _claims(iss="https://evil.example/auth/v1"), private, algorithm="ES256"
    )
    assert security.decode_supabase_token(good)["sub"] == "user-123"
    with pytest.raises(HTTPException) as excinfo:
        security.decode_supabase_token(bad)
    assert excinfo.value.status_code == 401


def test_es256_audience_enforced(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setenv("SUPABASE_URL", "https://proj.supabase.co")
    monkeypatch.setenv("SUPABASE_JWT_SECRET", "")
    get_settings.cache_clear()
    private, public = _es256()
    _use_jwks(monkeypatch, public)
    token = jwt.encode(_claims(iss=_ISSUER, aud="other"), private, algorithm="ES256")
    with pytest.raises(HTTPException) as excinfo:
        security.decode_supabase_token(token)
    assert excinfo.value.status_code == 401


def test_expired_es256_rejected(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setenv("SUPABASE_URL", "https://proj.supabase.co")
    monkeypatch.setenv("SUPABASE_JWT_SECRET", "")
    get_settings.cache_clear()
    private, public = _es256()
    _use_jwks(monkeypatch, public)
    token = jwt.encode(
        _claims(iss=_ISSUER, exp=int(time.time()) - 10), private, algorithm="ES256"
    )
    with pytest.raises(HTTPException) as excinfo:
        security.decode_supabase_token(token)
    assert excinfo.value.status_code == 401


# --------------------------------------------------------------------------- #
# Algorithm routing and error mapping
# --------------------------------------------------------------------------- #


def test_unsupported_algorithm_rejected(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setenv("SUPABASE_URL", "https://proj.supabase.co")
    monkeypatch.setenv("SUPABASE_JWT_SECRET", "test-secret")
    get_settings.cache_clear()
    # HS512 is outside the accepted HMAC set; it must never be trusted.
    token = jwt.encode(_claims(), "test-secret", algorithm="HS512")
    with pytest.raises(HTTPException) as excinfo:
        security.decode_supabase_token(token)
    assert excinfo.value.status_code == 401


@pytest.mark.parametrize("algorithm", ["ES384", "ES512", "RS384", "RS512"])
def test_unsupported_asymmetric_algorithm_rejected(
    monkeypatch: pytest.MonkeyPatch, algorithm: str
) -> None:
    monkeypatch.setenv("SUPABASE_URL", "https://proj.supabase.co")
    monkeypatch.setenv("SUPABASE_JWT_SECRET", "test-secret")
    get_settings.cache_clear()
    # Only ES256/RS256 are accepted; larger-curve/larger-RSA variants must be
    # rejected before any key lookup.
    if algorithm == "ES384":
        key = ec.generate_private_key(ec.SECP384R1())
    elif algorithm == "ES512":
        key = ec.generate_private_key(ec.SECP521R1())
    else:
        key = rsa.generate_private_key(public_exponent=65537, key_size=2048)
    token = jwt.encode(_claims(iss=_ISSUER), key, algorithm=algorithm)
    with pytest.raises(HTTPException) as excinfo:
        security.decode_supabase_token(token)
    assert excinfo.value.status_code == 401


def test_asymmetric_without_jwks_is_503(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setenv("SUPABASE_URL", "")
    monkeypatch.setenv("SUPABASE_JWKS_URL", "")
    monkeypatch.setenv("SUPABASE_JWT_SECRET", "test-secret")
    get_settings.cache_clear()
    private, _ = _es256()
    token = jwt.encode(_claims(), private, algorithm="ES256")
    with pytest.raises(HTTPException) as excinfo:
        security.decode_supabase_token(token)
    assert excinfo.value.status_code == 503


def test_asymmetric_jwks_only_without_issuer_is_503(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    monkeypatch.setenv("SUPABASE_URL", "")
    monkeypatch.setenv("SUPABASE_JWT_ISSUER", "")
    monkeypatch.setenv(
        "SUPABASE_JWKS_URL", "https://proj.supabase.co/auth/v1/.well-known/jwks.json"
    )
    monkeypatch.setenv("SUPABASE_JWT_SECRET", "")
    get_settings.cache_clear()
    private, public = _es256()
    _use_jwks(monkeypatch, public)
    token = jwt.encode(_claims(iss=_ISSUER), private, algorithm="ES256")
    with pytest.raises(HTTPException) as excinfo:
        security.decode_supabase_token(token)
    assert excinfo.value.status_code == 503


def test_asymmetric_jwks_only_with_explicit_issuer_accepted(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    monkeypatch.setenv("SUPABASE_URL", "")
    monkeypatch.setenv("SUPABASE_JWT_ISSUER", _ISSUER)
    monkeypatch.setenv(
        "SUPABASE_JWKS_URL", "https://proj.supabase.co/auth/v1/.well-known/jwks.json"
    )
    monkeypatch.setenv("SUPABASE_JWT_SECRET", "")
    get_settings.cache_clear()
    private, public = _es256()
    _use_jwks(monkeypatch, public)
    token = jwt.encode(_claims(iss=_ISSUER), private, algorithm="ES256")
    assert security.decode_supabase_token(token)["sub"] == "user-123"


def test_asymmetric_unknown_key_is_401(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setenv("SUPABASE_URL", "https://proj.supabase.co")
    get_settings.cache_clear()
    monkeypatch.setattr(
        security, "_get_jwks_client", lambda url: _UnknownKeyJwksClient()
    )
    private, _ = _es256()
    token = jwt.encode(_claims(iss=_ISSUER), private, algorithm="ES256")
    with pytest.raises(HTTPException) as excinfo:
        security.decode_supabase_token(token)
    assert excinfo.value.status_code == 401


def test_asymmetric_unreachable_jwks_is_503(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setenv("SUPABASE_URL", "https://proj.supabase.co")
    get_settings.cache_clear()
    monkeypatch.setattr(
        security, "_get_jwks_client", lambda url: _UnreachableJwksClient()
    )
    private, _ = _es256()
    token = jwt.encode(_claims(iss=_ISSUER), private, algorithm="ES256")
    with pytest.raises(HTTPException) as excinfo:
        security.decode_supabase_token(token)
    assert excinfo.value.status_code == 503


def test_asymmetric_empty_key_set_is_503(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setenv("SUPABASE_URL", "https://proj.supabase.co")
    get_settings.cache_clear()
    monkeypatch.setattr(
        security, "_get_jwks_client", lambda url: _EmptyKeySetJwksClient()
    )
    private, _ = _es256()
    token = jwt.encode(_claims(iss=_ISSUER), private, algorithm="ES256")
    with pytest.raises(HTTPException) as excinfo:
        security.decode_supabase_token(token)
    assert excinfo.value.status_code == 503
    assert excinfo.value.detail == "Authentication is temporarily unavailable."


def test_asymmetric_malformed_jwks_json_is_503(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setenv("SUPABASE_URL", "https://proj.supabase.co")
    get_settings.cache_clear()
    monkeypatch.setattr(
        security, "_get_jwks_client", lambda url: _MalformedJsonJwksClient()
    )
    private, _ = _es256()
    token = jwt.encode(_claims(iss=_ISSUER), private, algorithm="ES256")
    with pytest.raises(HTTPException) as excinfo:
        security.decode_supabase_token(token)
    assert excinfo.value.status_code == 503
    assert excinfo.value.detail == "Authentication is temporarily unavailable."


def test_malformed_token_is_401(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setenv("SUPABASE_URL", "https://proj.supabase.co")
    get_settings.cache_clear()
    with pytest.raises(HTTPException) as excinfo:
        security.decode_supabase_token("not-a-real-token")
    assert excinfo.value.status_code == 401
