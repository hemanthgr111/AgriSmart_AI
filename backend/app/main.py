"""AgriSmart AI FastAPI application entry point."""

import logging
from contextlib import asynccontextmanager

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from slowapi import _rate_limit_exceeded_handler
from slowapi.errors import RateLimitExceeded
from starlette.middleware.gzip import GZipMiddleware
from starlette.middleware.trustedhost import TrustedHostMiddleware

from app import __version__
from app.api.routes import chat, diagnosis, health, profile, weather
from app.core.config import get_settings
from app.core.logging import configure_logging
from app.core.middleware import MaxBodySizeMiddleware, SecurityHeadersMiddleware
from app.core.rate_limit import limiter

logger = logging.getLogger(__name__)


@asynccontextmanager
async def lifespan(_app: FastAPI):
    settings = get_settings()
    configure_logging(settings.debug)
    logger.info(
        "Starting %s v%s (env=%s)", settings.app_name, __version__, settings.environment
    )
    yield
    logger.info("Shutting down %s", settings.app_name)


def create_app() -> FastAPI:
    settings = get_settings()
    configure_logging(settings.debug)

    docs_enabled = settings.enable_api_docs
    app = FastAPI(
        title=settings.app_name,
        version=__version__,
        description="Backend API for the AgriSmart AI agriculture application.",
        docs_url="/docs" if docs_enabled else None,
        redoc_url="/redoc" if docs_enabled else None,
        openapi_url="/openapi.json" if docs_enabled else None,
        lifespan=lifespan,
    )

    # --- Rate limiting (per client IP) ---
    app.state.limiter = limiter
    app.add_exception_handler(RateLimitExceeded, _rate_limit_exceeded_handler)

    # --- Middleware ---
    # Added innermost-first; SecurityHeaders is added last so it wraps every
    # response (including CORS preflight and error responses).
    app.add_middleware(GZipMiddleware, minimum_size=settings.gzip_min_size)
    app.add_middleware(
        TrustedHostMiddleware, allowed_hosts=settings.allowed_host_list
    )
    app.add_middleware(MaxBodySizeMiddleware, max_bytes=settings.max_request_bytes)

    # A wildcard origin is incompatible with credentials; only allow them for
    # an explicit allow-list.
    wildcard = settings.cors_origin_list == ["*"]
    app.add_middleware(
        CORSMiddleware,
        allow_origins=settings.cors_origin_list,
        allow_credentials=not wildcard,
        allow_methods=["GET", "POST", "OPTIONS"],
        allow_headers=["Authorization", "Content-Type"],
    )

    if settings.security_headers_enabled:
        app.add_middleware(
            SecurityHeadersMiddleware, hsts=settings.is_production
        )

    # --- Routes ---
    app.include_router(health.router, prefix=settings.api_v1_prefix)
    app.include_router(profile.router, prefix=settings.api_v1_prefix)
    app.include_router(weather.router, prefix=settings.api_v1_prefix)
    app.include_router(diagnosis.router, prefix=settings.api_v1_prefix)
    app.include_router(chat.router, prefix=settings.api_v1_prefix)
    return app


app = create_app()
