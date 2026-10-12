"""Health endpoint tests."""


def test_health_ok(client):
    response = client.get("/api/health")
    assert response.status_code == 200
    body = response.json()
    assert body["status"] == "ok"
    assert body["app"]
    assert body["version"]
    # Database is expected to be unavailable without credentials in CI.
    assert body["database"] in {"connected", "unavailable"}
