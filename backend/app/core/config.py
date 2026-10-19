"""Application configuration loaded from environment variables.

All settings are read from the process environment (and an optional local
`.env` file for development). Secrets must never be hard-coded here.
"""

from functools import lru_cache

from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        case_sensitive=False,
        extra="ignore",
    )

    # --- App ---
    app_name: str = "AgriSmart AI"
    environment: str = "development"
    debug: bool = False
    api_v1_prefix: str = "/api"

    # --- Database ---
    database_url: str = ""

    # --- Supabase ---
    supabase_url: str = ""
    supabase_anon_key: str = ""
    supabase_service_role_key: str = ""
    supabase_jwt_secret: str = ""
    # Optional issuer to pin when verifying Supabase JWTs. When empty and
    # SUPABASE_URL is set, it defaults to "<SUPABASE_URL>/auth/v1".
    supabase_jwt_issuer: str = ""
    # Optional explicit JWKS endpoint for asymmetric (ES256/RS256) token
    # verification. When empty and SUPABASE_URL is set, it defaults to
    # "<SUPABASE_URL>/auth/v1/.well-known/jwks.json".
    supabase_jwks_url: str = ""
    # Accept legacy HS256 shared-secret tokens (ALLOW_LEGACY_HS256). Default
    # true preserves current behaviour; set false for asymmetric-only projects
    # so an HS256 token is rejected even when SUPABASE_JWT_SECRET is configured.
    allow_legacy_hs256: bool = True

    # --- Weather ---
    weather_api_key: str = ""
    weather_api_base_url: str = "https://api.weatherapi.com/v1"
    weather_cache_ttl_seconds: int = 600

    # --- AI provider ---
    ai_provider: str = "none"
    ai_api_key: str = ""
    ai_model: str = ""
    ai_base_url: str = ""
    ai_timeout_seconds: float = 30.0

    # --- Crop-disease model (PyTorch / TorchScript) ---
    # Path to a TorchScript model file. Empty means detection is disabled.
    model_path: str = ""
    model_input_size: int = 224

    # --- CORS (comma-separated) ---
    cors_origins: str = "*"

    # --- Media limits ---
    max_photo_bytes: int = 5 * 1024 * 1024
    max_video_bytes: int = 20 * 1024 * 1024
    max_video_duration_seconds: int = 30

    # --- Rate limiting (per client IP) ---
    rate_limit_enabled: bool = True
    rate_limit_chat: str = "20/minute"
    rate_limit_diagnose: str = "30/minute"
    rate_limit_weather: str = "60/minute"
    # In-memory by default (single instance). Use a Redis URI when scaling out.
    rate_limit_storage_uri: str = "memory://"
    # Comma-separated proxy IPs whose X-Forwarded-For header is trusted when
    # resolving a client's address. Empty means never trust the header and use
    # the socket peer address instead.
    trusted_proxy_ips: str = ""

    # --- Hardening / cost controls ---
    enable_api_docs: bool = True
    security_headers_enabled: bool = True
    gzip_min_size: int = 1024
    # Reject oversized request bodies before reading them into memory.
    max_request_bytes: int = 12 * 1024 * 1024
    # Comma-separated host allow-list for TrustedHostMiddleware ("*" = any).
    allowed_hosts: str = "*"
    # Caps the assistant's reply length to bound provider cost.
    ai_max_output_tokens: int = 800
    # When true, the AI/ML/weather endpoints require a valid Supabase token.
    # Default false preserves guest mode; enable in production to curb abuse.
    require_auth_for_ai: bool = False

    @property
    def cors_origin_list(self) -> list[str]:
        return [origin.strip() for origin in self.cors_origins.split(",") if origin.strip()]

    @property
    def trusted_proxy_ip_list(self) -> list[str]:
        return [ip.strip() for ip in self.trusted_proxy_ips.split(",") if ip.strip()]

    @property
    def expected_jwt_issuer(self) -> str:
        if self.supabase_jwt_issuer:
            return self.supabase_jwt_issuer.strip()
        if self.supabase_url:
            return f"{self.supabase_url.rstrip('/')}/auth/v1"
        return ""

    @property
    def expected_jwks_url(self) -> str:
        if self.supabase_jwks_url:
            return self.supabase_jwks_url.strip()
        if self.supabase_url:
            return f"{self.supabase_url.rstrip('/')}/auth/v1/.well-known/jwks.json"
        return ""

    @property
    def allowed_host_list(self) -> list[str]:
        hosts = [host.strip() for host in self.allowed_hosts.split(",") if host.strip()]
        return hosts or ["*"]

    @property
    def is_production(self) -> bool:
        return self.environment.lower() in {"production", "prod"}


@lru_cache
def get_settings() -> Settings:
    """Return a cached Settings instance."""
    return Settings()
