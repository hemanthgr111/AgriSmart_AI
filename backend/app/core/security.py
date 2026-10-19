"""Supabase JWT verification for protected endpoints.

Supabase issues access tokens signed either with the legacy shared secret
(HS256) or, for newer/migrated projects, an asymmetric key (ES256/RS256) whose
public key is published at the project's JWKS endpoint. This module verifies
both: HMAC tokens against ``SUPABASE_JWT_SECRET`` and asymmetric tokens against
the project JWKS derived from ``SUPABASE_URL`` (or ``SUPABASE_JWKS_URL``).

The algorithm is read from the token header and routed to the matching key
material, so an HMAC token is never validated with a public key (and vice
versa); this prevents algorithm-confusion attacks.
"""

from __future__ import annotations

import json
import logging

import jwt
from fastapi import HTTPException, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer

from app.core.config import get_settings

logger = logging.getLogger(__name__)

bearer_scheme = HTTPBearer(auto_error=False)

# Asymmetric algorithms Supabase issues: ECC P-256 (ES256, default) or RSA
# (RS256, optional). Any other algorithm is rejected.
_ASYMMETRIC_ALGORITHMS = frozenset({"ES256", "RS256"})
# Legacy shared-secret algorithm. Kept to HS256 to preserve prior behaviour.
_HMAC_ALGORITHMS = frozenset({"HS256"})

# PyJWT caches the fetched key set per client; reuse one client per JWKS URL.
_jwks_clients: dict[str, jwt.PyJWKClient] = {}


def _get_jwks_client(url: str) -> jwt.PyJWKClient:
    """Return a cached JWKS client for ``url`` (PyJWT caches fetched keys)."""
    client = _jwks_clients.get(url)
    if client is None:
        client = jwt.PyJWKClient(url, cache_keys=True)
        _jwks_clients[url] = client
    return client


def _unauthorized(detail: str = "Invalid authentication token.") -> HTTPException:
    return HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail=detail)


def _not_configured() -> HTTPException:
    return HTTPException(
        status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
        detail="Authentication is not configured on the server.",
    )


def _verify(token: str, key: object, algorithms: list[str], options: dict) -> dict:
    """Verify a token's signature/claims, mapping PyJWT errors to HTTP errors."""
    try:
        return jwt.decode(token, key, algorithms=algorithms, **options)
    except jwt.ExpiredSignatureError as exc:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Session expired. Please sign in again.",
        ) from exc
    except jwt.PyJWTError as exc:
        logger.info("Rejected invalid token: %s", type(exc).__name__)
        raise _unauthorized() from exc


def decode_supabase_token(token: str) -> dict:
    """Decode and validate a Supabase access token. Raises HTTPException on error."""
    settings = get_settings()

    options: dict = {
        "audience": "authenticated",
    }
    # Pin the issuing project when known (explicit SUPABASE_JWT_ISSUER or
    # derived from SUPABASE_URL). Left unset, legacy behaviour is preserved.
    issuer = settings.expected_jwt_issuer
    if issuer:
        options["issuer"] = issuer

    try:
        header = jwt.get_unverified_header(token)
    except jwt.PyJWTError as exc:
        logger.info("Rejected malformed token: %s", type(exc).__name__)
        raise _unauthorized() from exc

    algorithm = header.get("alg")

    if algorithm in _ASYMMETRIC_ALGORITHMS:
        jwks_url = settings.expected_jwks_url
        if not jwks_url:
            raise _not_configured()
        # Asymmetric tokens must be pinned to a trusted issuer; a JWKS-only
        # deployment (no SUPABASE_URL / SUPABASE_JWT_ISSUER) would otherwise
        # accept any issuer. Fail closed rather than skip iss validation.
        if not issuer:
            logger.warning(
                "Rejected asymmetric token: no expected issuer configured "
                "(set SUPABASE_URL or SUPABASE_JWT_ISSUER)"
            )
            raise _not_configured()
        try:
            signing_key = _get_jwks_client(jwks_url).get_signing_key_from_jwt(token).key
        except jwt.PyJWKClientConnectionError as exc:
            logger.warning("JWKS fetch failed: %s", type(exc).__name__)
            raise HTTPException(
                status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
                detail="Authentication is temporarily unavailable.",
            ) from exc
        except (jwt.PyJWKSetError, json.JSONDecodeError) as exc:
            # Endpoint answered but the key set was empty, unusable, or not
            # valid JSON: a retrieval problem, not an invalid credential.
            logger.warning("JWKS response unusable: %s", type(exc).__name__)
            raise HTTPException(
                status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
                detail="Authentication is temporarily unavailable.",
            ) from exc
        except jwt.PyJWKClientError as exc:
            logger.info(
                "Rejected token with unknown signing key: %s", type(exc).__name__
            )
            raise _unauthorized() from exc
        return _verify(token, signing_key, [algorithm], options)

    if algorithm in _HMAC_ALGORITHMS:
        if not settings.allow_legacy_hs256:
            logger.warning("Rejected HS256 token: legacy HS256 support is disabled")
            raise _unauthorized()
        if not settings.supabase_jwt_secret:
            raise _not_configured()
        return _verify(token, settings.supabase_jwt_secret, [algorithm], options)

    logger.info("Rejected token with unsupported algorithm")
    raise _unauthorized()


def user_id_from_credentials(
    credentials: HTTPAuthorizationCredentials | None,
) -> str:
    """Return the authenticated user's id (JWT `sub`) or raise 401."""
    if credentials is None or not credentials.credentials:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Missing authentication token.",
            headers={"WWW-Authenticate": "Bearer"},
        )
    payload = decode_supabase_token(credentials.credentials)
    subject = payload.get("sub")
    if not subject:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid authentication token.",
        )
    return str(subject)
