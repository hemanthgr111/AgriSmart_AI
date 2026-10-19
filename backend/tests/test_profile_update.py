"""Profile-update transaction tests (no database required)."""

from __future__ import annotations

import uuid
from datetime import UTC, datetime

import pytest

from app.api.deps import get_current_user_id, get_db
from app.main import app
from app.models.profile import Profile


def _seed_profile(user_id: uuid.UUID) -> Profile:
    now = datetime.now(UTC)
    return Profile(
        id=user_id,
        email="farmer@example.com",
        full_name="Old Name",
        avatar_url=None,
        bio=None,
        username=None,
        preferred_language=None,
        created_at=now,
        updated_at=now,
    )


def _override(user_id: uuid.UUID, session: object) -> None:
    app.dependency_overrides[get_db] = lambda: session
    app.dependency_overrides[get_current_user_id] = lambda: str(user_id)


class _RecordingSession:
    """Session double that only persists field values on commit()."""

    def __init__(self, profile: Profile) -> None:
        self.profile = profile
        self.committed: dict[str, object] | None = None
        self.rolled_back = False

    def get(self, model, key):
        return self.profile

    def add(self, instance):
        self.profile = instance

    def commit(self):
        self.committed = {
            "full_name": self.profile.full_name,
            "bio": self.profile.bio,
            "username": self.profile.username,
            "preferred_language": self.profile.preferred_language,
        }

    def refresh(self, instance):
        # A real session reloads the persisted row; without a commit there is
        # nothing persisted, so this must not invent values.
        if self.committed is not None:
            for field, value in self.committed.items():
                setattr(self.profile, field, value)

    def rollback(self):
        self.rolled_back = True


class _FailingSession(_RecordingSession):
    def commit(self):
        raise RuntimeError("simulated commit failure")


def test_update_profile_persists_changes(client):
    user_id = uuid.uuid4()
    session = _RecordingSession(_seed_profile(user_id))
    _override(user_id, session)
    try:
        response = client.put(
            "/api/profile",
            json={"full_name": "New Name", "bio": "  Hello farmers  "},
        )
    finally:
        app.dependency_overrides.clear()

    assert response.status_code == 200
    body = response.json()
    assert body["full_name"] == "New Name"
    assert body["bio"] == "Hello farmers"
    # The update must be committed (persisted), not merely mutated in memory.
    assert session.committed is not None, "profile update did not commit"
    assert session.committed["full_name"] == "New Name"
    assert session.committed["bio"] == "Hello farmers"
    assert session.rolled_back is False


def test_update_profile_rolls_back_on_failure(client):
    user_id = uuid.uuid4()
    session = _FailingSession(_seed_profile(user_id))
    _override(user_id, session)
    try:
        with pytest.raises(RuntimeError):
            client.put("/api/profile", json={"full_name": "New Name"})
    finally:
        app.dependency_overrides.clear()

    assert session.rolled_back is True
