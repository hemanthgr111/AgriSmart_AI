"""Crop-disease diagnosis endpoint (image upload + model inference)."""

from __future__ import annotations

from fastapi import APIRouter, Depends, File, HTTPException, Request, UploadFile

from app.api.deps import require_ai_access
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

# Uploads are read in bounded chunks so an oversized (or chunked, length-less)
# body can never be buffered fully into memory. `application/octet-stream` is
# accepted because some clients (e.g. Dart's http multipart) send it by default;
# the image decoder is the real validator.
_READ_CHUNK_BYTES = 64 * 1024
_ALLOWED_OPAQUE_TYPES = {"application/octet-stream"}


def _content_type_allowed(content_type: str | None) -> bool:
    if not content_type:
        return True
    value = content_type.split(";")[0].strip().lower()
    return value.startswith("image/") or value in _ALLOWED_OPAQUE_TYPES


async def _read_bounded(file: UploadFile, limit: int) -> bytes:
    """Read an upload in chunks, aborting as soon as ``limit`` is exceeded.

    Never relies on ``Content-Length`` (which may be missing or inaccurate) and
    never buffers more than ``limit`` plus one chunk in memory.
    """
    buffer = bytearray()
    while True:
        chunk = await file.read(_READ_CHUNK_BYTES)
        if not chunk:
            break
        buffer.extend(chunk)
        if len(buffer) > limit:
            raise HTTPException(
                status_code=413,
                detail="Image is too large. Use a smaller photo.",
            )
    return bytes(buffer)


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
async def diagnose(
    request: Request,
    file: UploadFile = File(...),
    _auth: None = Depends(require_ai_access),
) -> DiagnosisResponse:
    """Classify a leaf photo and return the most likely crop disease.

    Accepts a single image upload. The upload is read in bounded chunks so a
    missing/incorrect Content-Length cannot force unbounded buffering. The model
    runs server-side; if no model is configured the endpoint returns 503 rather
    than guessing. Image authenticity is validated by the decoder in
    ``classify`` (PIL), not by the declared MIME type or filename.
    """
    settings = get_settings()

    if not _content_type_allowed(file.content_type):
        raise HTTPException(
            status_code=415,
            detail="Unsupported file type. Upload a JPEG or PNG image.",
        )

    contents = await _read_bounded(file, settings.max_photo_bytes)
    if not contents:
        raise HTTPException(status_code=400, detail="The uploaded file is empty.")

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
