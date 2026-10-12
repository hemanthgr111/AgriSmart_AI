"""Crop-disease inference using a TorchScript model.

Design goals:
- The module imports cleanly even when PyTorch is not installed.
- The model is loaded lazily, once, from ``settings.model_path`` and cached.
- If the model file is missing, a clear ``ModelUnavailable`` error is raised so
  the API can respond with 503 instead of fabricating a prediction.
"""

from __future__ import annotations

import io
from dataclasses import dataclass
from threading import Lock
from typing import Any

from PIL import Image, UnidentifiedImageError

from app.core.config import get_settings
from app.ml.labels import CLASSES, CropDisease, describe


class ModelUnavailable(Exception):
    """Raised when no usable model is configured or loadable."""


class InvalidImage(Exception):
    """Raised when the uploaded bytes are not a usable image."""


# ImageNet normalization (matches the training transforms in ml/train.py).
_MEAN = (0.485, 0.456, 0.406)
_STD = (0.229, 0.224, 0.225)

_model: Any = None
_model_path: str | None = None
_lock = Lock()


@dataclass(frozen=True)
class Prediction:
    class_index: int
    label: str
    confidence: float
    crop_disease: CropDisease


def model_is_configured() -> bool:
    """True when a model path is set (does not guarantee it loads)."""
    return bool(get_settings().model_path)


def _load_model(path: str) -> Any:
    try:
        import torch  # noqa: PLC0415 - optional, imported lazily on purpose
    except ImportError as exc:  # pragma: no cover - depends on environment
        raise ModelUnavailable(
            "PyTorch is not installed on the server."
        ) from exc

    try:
        model = torch.jit.load(path, map_location="cpu")
    except (OSError, RuntimeError, ValueError) as exc:
        raise ModelUnavailable("The crop-disease model could not be loaded.") from exc
    model.eval()
    return model


def _get_model() -> Any:
    global _model, _model_path
    settings = get_settings()
    if not settings.model_path:
        raise ModelUnavailable("Crop-disease detection is not configured.")

    with _lock:
        if _model is None or _model_path != settings.model_path:
            _model = _load_model(settings.model_path)
            _model_path = settings.model_path
        return _model


def reset_model_cache() -> None:
    """Clear the cached model (used by tests)."""
    global _model, _model_path
    with _lock:
        _model = None
        _model_path = None


def _open_image(image_bytes: bytes) -> Image.Image:
    if not image_bytes:
        raise InvalidImage("The uploaded file is empty.")
    try:
        image = Image.open(io.BytesIO(image_bytes))
        image.load()
    except (UnidentifiedImageError, OSError) as exc:
        raise InvalidImage("The uploaded file is not a valid image.") from exc
    return image.convert("RGB")


def preprocess(image_bytes: bytes, size: int) -> Any:
    """Turn raw image bytes into a normalized 1x3xSxS float tensor."""
    import numpy as np  # noqa: PLC0415
    import torch  # noqa: PLC0415

    image = _open_image(image_bytes).resize((size, size))
    array = np.asarray(image, dtype=np.float32) / 255.0
    array = (array - np.asarray(_MEAN, dtype=np.float32)) / np.asarray(
        _STD, dtype=np.float32
    )
    tensor = torch.from_numpy(array.transpose(2, 0, 1)).unsqueeze(0)
    return tensor.contiguous()


def classify(image_bytes: bytes, top_k: int = 3) -> list[Prediction]:
    """Run inference and return the top-k predictions, best first."""
    settings = get_settings()
    model = _get_model()

    import torch  # noqa: PLC0415 - available once a model has loaded

    tensor = preprocess(image_bytes, settings.model_input_size)

    with torch.no_grad():
        logits = model(tensor)
        if logits.dim() == 2:
            logits = logits[0]
        probabilities = torch.softmax(logits, dim=0)

    k = max(1, min(top_k, probabilities.shape[0], len(CLASSES)))
    scores, indices = torch.topk(probabilities, k)

    predictions: list[Prediction] = []
    for score, index in zip(scores.tolist(), indices.tolist()):
        label = CLASSES[index] if 0 <= index < len(CLASSES) else f"class_{index}"
        predictions.append(
            Prediction(
                class_index=int(index),
                label=label,
                confidence=float(score),
                crop_disease=describe(label),
            )
        )
    return predictions
