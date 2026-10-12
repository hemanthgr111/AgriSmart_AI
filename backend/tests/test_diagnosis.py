"""Crop-disease diagnosis tests.

These do not require PyTorch or a trained model: they cover label metadata,
input validation, the 503 path when no model is configured, and the response
mapping using a stubbed classifier.
"""

from __future__ import annotations

import pytest
from fastapi.testclient import TestClient

from app.api.routes import diagnosis as diagnosis_route
from app.core.config import get_settings
from app.ml import labels
from app.ml.labels import CLASSES, describe
from app.ml.predictor import (
    InvalidImage,
    ModelUnavailable,
    Prediction,
    _open_image,
)


def test_classes_are_38_and_unique() -> None:
    assert len(CLASSES) == 38
    assert len(set(CLASSES)) == 38


def test_describe_known_disease() -> None:
    info = describe("Tomato___Late_blight")
    assert info.crop == "Tomato"
    assert info.disease == "Late blight"
    assert info.is_healthy is False
    assert info.advice


def test_describe_healthy_label() -> None:
    info = describe("Apple___healthy")
    assert info.crop == "Apple"
    assert info.is_healthy is True
    assert info.advice


def test_every_class_has_metadata() -> None:
    for label in CLASSES:
        info = describe(label)
        assert info.crop != "Unknown", label
        assert info.disease, label
        assert info.advice, label


def test_describe_unknown_label_falls_back() -> None:
    info = describe("Something___Odd")
    assert info.crop == "Unknown"
    assert info.advice


def test_open_image_rejects_garbage() -> None:
    with pytest.raises(InvalidImage):
        _open_image(b"this is not an image")


def test_diagnose_returns_503_without_model(client: TestClient) -> None:
    response = client.post(
        "/api/diagnose",
        files={"file": ("leaf.jpg", b"\xff\xd8\xff\xe0fakejpeg", "image/jpeg")},
    )
    assert response.status_code == 503
    assert "not configured" in response.json()["detail"].lower()


def test_diagnose_rejects_empty_file(client: TestClient) -> None:
    response = client.post(
        "/api/diagnose",
        files={"file": ("leaf.jpg", b"", "image/jpeg")},
    )
    assert response.status_code == 400


def test_diagnose_rejects_oversized_file(
    client: TestClient, monkeypatch: pytest.MonkeyPatch
) -> None:
    monkeypatch.setattr(get_settings(), "max_photo_bytes", 4)
    response = client.post(
        "/api/diagnose",
        files={"file": ("leaf.jpg", b"12345", "image/jpeg")},
    )
    assert response.status_code == 413


def test_diagnose_maps_invalid_image_to_400(
    client: TestClient, monkeypatch: pytest.MonkeyPatch
) -> None:
    def fake_classify(_data: bytes, top_k: int = 3) -> list[Prediction]:
        raise InvalidImage("The uploaded file is not a valid image.")

    monkeypatch.setattr(diagnosis_route, "classify", fake_classify)
    response = client.post(
        "/api/diagnose",
        files={"file": ("leaf.jpg", b"not-an-image", "image/jpeg")},
    )
    assert response.status_code == 400
    assert "not a valid image" in response.json()["detail"].lower()


def test_diagnose_maps_predictions_to_response(
    client: TestClient, monkeypatch: pytest.MonkeyPatch
) -> None:
    def fake_classify(_data: bytes, top_k: int = 3) -> list[Prediction]:
        return [
            Prediction(
                class_index=30,
                label="Tomato___Late_blight",
                confidence=0.82,
                crop_disease=labels.describe("Tomato___Late_blight"),
            ),
            Prediction(
                class_index=29,
                label="Tomato___Early_blight",
                confidence=0.12,
                crop_disease=labels.describe("Tomato___Early_blight"),
            ),
        ]

    monkeypatch.setattr(diagnosis_route, "classify", fake_classify)

    response = client.post(
        "/api/diagnose",
        files={"file": ("leaf.jpg", b"fake-image-bytes", "image/jpeg")},
    )
    assert response.status_code == 200
    body = response.json()
    assert body["crop"] == "Tomato"
    assert body["disease"] == "Late blight"
    assert body["is_healthy"] is False
    assert body["confidence"] == pytest.approx(0.82)
    assert len(body["predictions"]) == 2
    assert body["predictions"][0]["label"] == "Tomato___Late_blight"


def test_model_unavailable_is_raised_when_unconfigured() -> None:
    from app.ml.predictor import classify

    with pytest.raises(ModelUnavailable):
        classify(b"anything")


def test_classify_with_scripted_model(
    tmp_path, monkeypatch: pytest.MonkeyPatch
) -> None:
    """Exercise the real inference path when PyTorch is installed."""
    torch = pytest.importorskip("torch")
    import io

    import numpy as np
    from PIL import Image
    from torch import nn

    from app.ml import predictor

    class Tiny(nn.Module):
        def __init__(self) -> None:
            super().__init__()
            self.fc = nn.Linear(3 * 8 * 8, 38)

        def forward(self, x):
            x = nn.functional.adaptive_avg_pool2d(x, 8)
            return self.fc(x.flatten(1))

    model = Tiny().eval()
    scripted = torch.jit.trace(model, torch.randn(1, 3, 224, 224))
    model_path = tmp_path / "model.pt"
    scripted.save(str(model_path))

    monkeypatch.setattr(get_settings(), "model_path", str(model_path))
    predictor.reset_model_cache()
    try:
        image = Image.fromarray((np.random.rand(64, 64, 3) * 255).astype("uint8"))
        buffer = io.BytesIO()
        image.save(buffer, format="JPEG")

        predictions = predictor.classify(buffer.getvalue(), top_k=3)
    finally:
        predictor.reset_model_cache()

    assert len(predictions) == 3
    assert all(0.0 <= p.confidence <= 1.0 for p in predictions)
    assert all(p.crop_disease.crop for p in predictions)
