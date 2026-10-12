"""Train and export the crop-disease classifier (offline tooling).

This script is NOT part of the running API. Run it once, locally or on a
machine with enough CPU/GPU, to produce a TorchScript model that the backend
loads at runtime via ``MODEL_PATH``.

Dataset: the standard 38-class PlantVillage / "New Plant Diseases" dataset laid
out as an ``ImageFolder`` with ``train/`` and ``val/`` splits::

    data/
      train/
        Apple___Apple_scab/ *.jpg
        ...
      val/
        Apple___Apple_scab/ *.jpg
        ...

Usage:
    pip install -r requirements.txt -r requirements-ml.txt
    python ml/train.py --data-dir data --output models/crop_disease.pt --epochs 4

The exported file is a TorchScript module expecting a float tensor of shape
(1, 3, 224, 224) normalized with ImageNet statistics, and returning logits in
the exact order of ``app/ml/labels.py:CLASSES``.
"""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

import torch
from torch import nn
from torch.utils.data import DataLoader
from torchvision import datasets, transforms
from torchvision.models import MobileNet_V3_Small_Weights, mobilenet_v3_small

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from app.ml.labels import CLASSES  # noqa: E402

IMAGE_SIZE = 224
MEAN = (0.485, 0.456, 0.406)
STD = (0.229, 0.224, 0.225)


def build_loaders(data_dir: Path, batch_size: int) -> tuple[DataLoader, DataLoader, list[str]]:
    train_tf = transforms.Compose(
        [
            transforms.RandomResizedCrop(IMAGE_SIZE),
            transforms.RandomHorizontalFlip(),
            transforms.ToTensor(),
            transforms.Normalize(MEAN, STD),
        ]
    )
    val_tf = transforms.Compose(
        [
            transforms.Resize(int(IMAGE_SIZE * 1.14)),
            transforms.CenterCrop(IMAGE_SIZE),
            transforms.ToTensor(),
            transforms.Normalize(MEAN, STD),
        ]
    )

    train_ds = datasets.ImageFolder(data_dir / "train", transform=train_tf)
    val_ds = datasets.ImageFolder(data_dir / "val", transform=val_tf)

    if train_ds.classes != val_ds.classes:
        raise SystemExit("train/ and val/ have different class folders.")
    # ImageFolder sorts folders alphabetically; our CLASSES list is authored in
    # that same order. Abort loudly if they ever diverge.
    if sorted(train_ds.classes) != sorted(CLASSES):
        raise SystemExit(
            "Folder names do not match app/ml/labels.py:CLASSES. "
            "Update labels.py to match the dataset before training."
        )

    train_loader = DataLoader(
        train_ds, batch_size=batch_size, shuffle=True, num_workers=2
    )
    val_loader = DataLoader(val_ds, batch_size=batch_size, num_workers=2)
    return train_loader, val_loader, train_ds.classes


def build_model(num_classes: int) -> nn.Module:
    model = mobilenet_v3_small(weights=MobileNet_V3_Small_Weights.DEFAULT)
    in_features = model.classifier[-1].in_features
    model.classifier[-1] = nn.Linear(in_features, num_classes)
    return model


def train(
    model: nn.Module,
    train_loader: DataLoader,
    val_loader: DataLoader,
    *,
    epochs: int,
    lr: float,
    device: torch.device,
) -> None:
    model.to(device)
    criterion = nn.CrossEntropyLoss()
    optimizer = torch.optim.AdamW(model.parameters(), lr=lr)

    for epoch in range(1, epochs + 1):
        model.train()
        running = 0.0
        for images, targets in train_loader:
            images, targets = images.to(device), targets.to(device)
            optimizer.zero_grad()
            loss = criterion(model(images), targets)
            loss.backward()
            optimizer.step()
            running += loss.item() * images.size(0)
        train_loss = running / len(train_loader.dataset)

        model.eval()
        correct = total = 0
        with torch.no_grad():
            for images, targets in val_loader:
                images, targets = images.to(device), targets.to(device)
                preds = model(images).argmax(dim=1)
                correct += (preds == targets).sum().item()
                total += targets.size(0)
        print(
            f"epoch {epoch}/{epochs} - train_loss={train_loss:.4f} "
            f"- val_acc={correct / max(total, 1):.4f}"
        )


def export(model: nn.Module, output: Path, device: torch.device) -> None:
    model.eval().to("cpu" if device.type == "cuda" else device)
    example = torch.randn(1, 3, IMAGE_SIZE, IMAGE_SIZE)
    scripted = torch.jit.trace(model, example)
    output.parent.mkdir(parents=True, exist_ok=True)
    scripted.save(str(output))
    print(f"Saved TorchScript model to {output}")


def main() -> None:
    parser = argparse.ArgumentParser(description="Train the crop-disease model.")
    parser.add_argument("--data-dir", type=Path, default=Path("data"))
    parser.add_argument("--output", type=Path, default=Path("models/crop_disease.pt"))
    parser.add_argument("--epochs", type=int, default=4)
    parser.add_argument("--batch-size", type=int, default=32)
    parser.add_argument("--lr", type=float, default=1e-3)
    args = parser.parse_args()

    device = torch.device("cuda" if torch.cuda.is_available() else "cpu")
    print(f"Using device: {device}")

    train_loader, val_loader, classes = build_loaders(args.data_dir, args.batch_size)
    model = build_model(len(classes))
    train(
        model,
        train_loader,
        val_loader,
        epochs=args.epochs,
        lr=args.lr,
        device=device,
    )
    export(model, args.output, device)


if __name__ == "__main__":
    main()
