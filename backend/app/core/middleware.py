"""Small ASGI middlewares for security headers and request-size limits.

These are intentionally dependency-free and stateless so they are trivial to
test. Rate limiting lives in ``app.core.rate_limit``.
"""

from __future__ import annotations

from starlette.middleware.base import BaseHTTPMiddleware
from starlette.requests import Request
from starlette.responses import JSONResponse, Response
from starlette.types import ASGIApp

# Conservative defaults. These are set with ``setdefault`` so a route (e.g. the
# docs UI) can override a value when it needs to.
_SECURITY_HEADERS: dict[str, str] = {
    "X-Content-Type-Options": "nosniff",
    "X-Frame-Options": "DENY",
    "Referrer-Policy": "no-referrer",
    "Permissions-Policy": "geolocation=(self), camera=(self), microphone=()",
    "Cross-Origin-Opener-Policy": "same-origin",
}

_HSTS_VALUE = "max-age=31536000; includeSubDomains"


class SecurityHeadersMiddleware(BaseHTTPMiddleware):
    """Attach hardening headers to every response (including errors)."""

    def __init__(self, app: ASGIApp, *, hsts: bool = False) -> None:
        super().__init__(app)
        self._hsts = hsts

    async def dispatch(self, request: Request, call_next) -> Response:
        response = await call_next(request)
        for header, value in _SECURITY_HEADERS.items():
            response.headers.setdefault(header, value)
        if self._hsts:
            response.headers.setdefault("Strict-Transport-Security", _HSTS_VALUE)
        return response


class MaxBodySizeMiddleware(BaseHTTPMiddleware):
    """Reject requests whose declared body exceeds ``max_bytes`` with 413.

    Relies on the ``Content-Length`` header sent by well-behaved clients; the
    upload endpoints additionally enforce their own limits after reading.
    """

    def __init__(self, app: ASGIApp, *, max_bytes: int) -> None:
        super().__init__(app)
        self._max_bytes = max_bytes

    async def dispatch(self, request: Request, call_next) -> Response:
        content_length = request.headers.get("content-length")
        if content_length is not None:
            try:
                declared = int(content_length)
            except ValueError:
                return JSONResponse(
                    {"detail": "Invalid Content-Length header."}, status_code=400
                )
            if declared > self._max_bytes:
                return JSONResponse(
                    {"detail": "Request body is too large."}, status_code=413
                )
        return await call_next(request)
