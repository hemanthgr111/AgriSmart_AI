"""Profile endpoint authorization tests (no database required)."""


def test_profile_requires_authentication(client):
    response = client.get("/api/profile")
    assert response.status_code == 401
    assert "authentication" in response.json()["detail"].lower()


def test_profile_rejects_invalid_token(client):
    response = client.get(
        "/api/profile",
        headers={"Authorization": "Bearer not-a-real-token"},
    )
    # Without a configured JWT secret this is 503; with one it is 401.
    # Either way the request must never succeed.
    assert response.status_code in {401, 503}
