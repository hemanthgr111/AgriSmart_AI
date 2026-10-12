"""Crop-disease diagnosis response schemas."""

from __future__ import annotations

from pydantic import BaseModel, Field


class DiagnosisPrediction(BaseModel):
    """A single class prediction from the model."""

    label: str
    crop: str
    disease: str
    is_healthy: bool
    confidence: float = Field(ge=0.0, le=1.0)
    advice: str


class DiagnosisResponse(BaseModel):
    """Top prediction plus the runner-up classes the model considered."""

    crop: str
    disease: str
    is_healthy: bool
    confidence: float = Field(ge=0.0, le=1.0)
    advice: str
    predictions: list[DiagnosisPrediction]
