"""Crop-disease diagnosis endpoint (image upload + model inference)."""

from __future__ import annotations

from fastapi import APIRouter, File, HTTPException, Request, UploadFile

from app.core.config import get_settings
from app.core.rate_limit import DIAGNOSE_RATE_LIMIT, limiter
from app.ml.predictor import (
    InvalidImage,
    ModelUnavailable,
    Prediction,
    classify,
)
from app.schemas.diagnosis import DiagnosisPrediction, DiagnosisResponse

router = APIRouter(prefix="/diagnose", tags=["diagnosis"])


def _to_schema(prediction: Prediction) -> DiagnosisPrediction:
    info = prediction.crop_disease
    return DiagnosisPrediction(
        label=info.label,
        crop=info.crop,
        disease=info.disease,
        is_healthy=info.is_healthy,
        confidence=prediction.confidence,
        advice=info.advice,
    )


@router.post("", response_model=DiagnosisResponse)
@limiter.limit(DIAGNOSE_RATE_LIMIT)
async def diagnose(request: Request, file: UploadFile = File(...)) -> DiagnosisResponse:
    """Classify a leaf photo and return the most likely crop disease.

    Accepts a single image upload. The model runs server-side; if no model is
    configured the endpoint returns 503 rather than guessing.
    """
    settings = get_settings()
    contents = await file.read()
    if not contents:
        raise HTTPException(status_code=400, detail="The uploaded file is empty.")
    if len(contents) > settings.max_photo_bytes:
        raise HTTPException(
            status_code=413,
            detail="Image is too large. Use a smaller photo.",
        )

    try:
        predictions = classify(contents, top_k=3)
    except InvalidImage as error:
        raise HTTPException(status_code=400, detail=str(error)) from error
    except ModelUnavailable as error:
        raise HTTPException(status_code=503, detail=str(error)) from error

    best = predictions[0]
    info = best.crop_disease
    return DiagnosisResponse(
        crop=info.crop,
        disease=info.disease,
        is_healthy=info.is_healthy,
        confidence=best.confidence,
        advice=info.advice,
        predictions=[_to_schema(prediction) for prediction in predictions],
    )
