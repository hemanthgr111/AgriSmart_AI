"""User profile endpoints."""

from __future__ import annotations

import uuid

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from app.api.deps import get_current_user_id, get_db
from app.models.profile import Profile
from app.schemas.profile import ProfileResponse, ProfileUpdate

router = APIRouter(prefix="/profile", tags=["profile"])


def _parse_user_id(user_id: str) -> uuid.UUID:
    try:
        return uuid.UUID(user_id)
    except ValueError as exc:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid authentication token.",
        ) from exc


@router.get("", response_model=ProfileResponse)
def get_my_profile(
    user_id: str = Depends(get_current_user_id),
    db: Session = Depends(get_db),
) -> Profile:
    profile = db.get(Profile, _parse_user_id(user_id))
    if profile is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Profile not found.",
        )
    return profile


@router.put("", response_model=ProfileResponse)
def update_my_profile(
    payload: ProfileUpdate,
    user_id: str = Depends(get_current_user_id),
    db: Session = Depends(get_db),
) -> Profile:
    uid = _parse_user_id(user_id)
    profile = db.get(Profile, uid)
    if profile is None:
        profile = Profile(id=uid)
        db.add(profile)
    try:
        if payload.full_name is not None:
            profile.full_name = payload.full_name.strip() or None
        if payload.bio is not None:
            profile.bio = payload.bio.strip() or None
        if payload.username is not None:
            profile.username = payload.username.strip() or None
        if payload.preferred_language is not None:
            profile.preferred_language = payload.preferred_language.strip() or None
        db.commit()
    except IntegrityError as exc:
        db.rollback()
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="That username is already taken.",
        ) from exc
    except Exception:
        db.rollback()
        raise
    db.refresh(profile)
    return profile
