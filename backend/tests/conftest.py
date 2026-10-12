"""Pytest fixtures for the AgriSmart AI backend."""

import os
import sys

import pytest
from fastapi.testclient import TestClient

sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))

# Disable rate limiting for the default test client so unrelated tests never
# trip a limit. The dedicated rate-limit test enables the limiter explicitly.
os.environ["RATE_LIMIT_ENABLED"] = "false"

from app.main import app  # noqa: E402


@pytest.fixture()
def client() -> TestClient:
    with TestClient(app) as test_client:
        yield test_client
