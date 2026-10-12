"""PlantVillage label metadata for crop-disease classification.

The model is trained on the standard 38-class PlantVillage dataset. Class
folder names follow the dataset's canonical spelling (underscores and all),
so this file is the single source of truth mapping a raw class name to a
human-readable crop, disease, and generic care advice.

Advice here is intentionally general guidance, not a prescription. It is shown
alongside the model's prediction and confidence; it is never a substitute for
local agricultural extension advice.
"""

from __future__ import annotations

from dataclasses import dataclass

# Canonical 38-class ordering. Index i corresponds to output logit i.
CLASSES: list[str] = [
    "Apple___Apple_scab",
    "Apple___Black_rot",
    "Apple___Cedar_apple_rust",
    "Apple___healthy",
    "Blueberry___healthy",
    "Cherry_(including_sour)___Powdery_mildew",
    "Cherry_(including_sour)___healthy",
    "Corn_(maize)___Cercospora_leaf_spot Gray_leaf_spot",
    "Corn_(maize)___Common_rust_",
    "Corn_(maize)___Northern_Leaf_Blight",
    "Corn_(maize)___healthy",
    "Grape___Black_rot",
    "Grape___Esca_(Black_Measles)",
    "Grape___Leaf_blight_(Isariopsis_Leaf_Spot)",
    "Grape___healthy",
    "Orange___Haunglongbing_(Citrus_greening)",
    "Peach___Bacterial_spot",
    "Peach___healthy",
    "Pepper,_bell___Bacterial_spot",
    "Pepper,_bell___healthy",
    "Potato___Early_blight",
    "Potato___Late_blight",
    "Potato___healthy",
    "Raspberry___healthy",
    "Soybean___healthy",
    "Squash___Powdery_mildew",
    "Strawberry___Leaf_scorch",
    "Strawberry___healthy",
    "Tomato___Bacterial_spot",
    "Tomato___Early_blight",
    "Tomato___Late_blight",
    "Tomato___Leaf_Mold",
    "Tomato___Septoria_leaf_spot",
    "Tomato___Spider_mites Two-spotted_spider_mite",
    "Tomato___Target_Spot",
    "Tomato___Tomato_Yellow_Leaf_Curl_Virus",
    "Tomato___Tomato_mosaic_virus",
    "Tomato___healthy",
]

# Raw class -> (crop, disease, is_healthy)
_CLASS_INFO: dict[str, tuple[str, str, bool]] = {
    "Apple___Apple_scab": ("Apple", "Apple scab", False),
    "Apple___Black_rot": ("Apple", "Black rot", False),
    "Apple___Cedar_apple_rust": ("Apple", "Cedar apple rust", False),
    "Apple___healthy": ("Apple", "Healthy", True),
    "Blueberry___healthy": ("Blueberry", "Healthy", True),
    "Cherry_(including_sour)___Powdery_mildew": (
        "Cherry",
        "Powdery mildew",
        False,
    ),
    "Cherry_(including_sour)___healthy": ("Cherry", "Healthy", True),
    "Corn_(maize)___Cercospora_leaf_spot Gray_leaf_spot": (
        "Corn",
        "Gray leaf spot (Cercospora)",
        False,
    ),
    "Corn_(maize)___Common_rust_": ("Corn", "Common rust", False),
    "Corn_(maize)___Northern_Leaf_Blight": (
        "Corn",
        "Northern leaf blight",
        False,
    ),
    "Corn_(maize)___healthy": ("Corn", "Healthy", True),
    "Grape___Black_rot": ("Grape", "Black rot", False),
    "Grape___Esca_(Black_Measles)": ("Grape", "Esca (black measles)", False),
    "Grape___Leaf_blight_(Isariopsis_Leaf_Spot)": (
        "Grape",
        "Leaf blight (Isariopsis)",
        False,
    ),
    "Grape___healthy": ("Grape", "Healthy", True),
    "Orange___Haunglongbing_(Citrus_greening)": (
        "Orange",
        "Huanglongbing (citrus greening)",
        False,
    ),
    "Peach___Bacterial_spot": ("Peach", "Bacterial spot", False),
    "Peach___healthy": ("Peach", "Healthy", True),
    "Pepper,_bell___Bacterial_spot": ("Bell pepper", "Bacterial spot", False),
    "Pepper,_bell___healthy": ("Bell pepper", "Healthy", True),
    "Potato___Early_blight": ("Potato", "Early blight", False),
    "Potato___Late_blight": ("Potato", "Late blight", False),
    "Potato___healthy": ("Potato", "Healthy", True),
    "Raspberry___healthy": ("Raspberry", "Healthy", True),
    "Soybean___healthy": ("Soybean", "Healthy", True),
    "Squash___Powdery_mildew": ("Squash", "Powdery mildew", False),
    "Strawberry___Leaf_scorch": ("Strawberry", "Leaf scorch", False),
    "Strawberry___healthy": ("Strawberry", "Healthy", True),
    "Tomato___Bacterial_spot": ("Tomato", "Bacterial spot", False),
    "Tomato___Early_blight": ("Tomato", "Early blight", False),
    "Tomato___Late_blight": ("Tomato", "Late blight", False),
    "Tomato___Leaf_Mold": ("Tomato", "Leaf mold", False),
    "Tomato___Septoria_leaf_spot": ("Tomato", "Septoria leaf spot", False),
    "Tomato___Spider_mites Two-spotted_spider_mite": (
        "Tomato",
        "Two-spotted spider mite",
        False,
    ),
    "Tomato___Target_Spot": ("Tomato", "Target spot", False),
    "Tomato___Tomato_Yellow_Leaf_Curl_Virus": (
        "Tomato",
        "Yellow leaf curl virus",
        False,
    ),
    "Tomato___Tomato_mosaic_virus": ("Tomato", "Mosaic virus", False),
    "Tomato___healthy": ("Tomato", "Healthy", True),
}

# Generic, non-prescriptive advice keyed by disease family.
_ADVICE: dict[str, str] = {
    "Apple scab": (
        "Remove and destroy fallen leaves; improve airflow by pruning. "
        "A copper- or sulfur-based fungicide at bud break is commonly used."
    ),
    "Black rot": (
        "Prune out infected canes and fruit, and remove nearby weeds. "
        "Apply a labelled fungicide during the growing season."
    ),
    "Cedar apple rust": (
        "Remove nearby juniper/cedar hosts where practical. "
        "Protective fungicide sprays in spring are commonly used."
    ),
    "Powdery mildew": (
        "Improve air circulation and avoid overhead watering. "
        "Sulfur or potassium-bicarbonate sprays are commonly used."
    ),
    "Gray leaf spot (Cercospora)": (
        "Rotate crops and till residue into the soil. "
        "A strobilurin or triazole fungicide may be used per label."
    ),
    "Common rust": (
        "Plant resistant hybrids and remove volunteer plants. "
        "Fungicide is usually only needed on susceptible varieties."
    ),
    "Northern leaf blight": (
        "Rotate away from corn and bury residue. "
        "Fungicide at tasselling is commonly used on susceptible hybrids."
    ),
    "Esca (black measles)": (
        "Prune out affected wood and disinfect tools between cuts. "
        "There is no reliable cure; maintain vine vigour."
    ),
    "Leaf blight (Isariopsis)": (
        "Remove infected leaves and improve airflow. "
        "A labelled fungicide can slow spread."
    ),
    "Huanglongbing (citrus greening)": (
        "There is no cure. Remove and destroy affected trees and manage the "
        "psyllid vector with approved insecticides."
    ),
    "Bacterial spot": (
        "Use certified disease-free seed/transplants and rotate crops. "
        "Copper-based sprays can reduce spread."
    ),
    "Early blight": (
        "Rotate crops, mulch to stop soil splash, and remove infected leaves. "
        "Chlorothalonil or copper fungicides are commonly used."
    ),
    "Late blight": (
        "Act quickly: remove and destroy infected plants and avoid overhead "
        "watering. A protectant fungicide may be applied per label."
    ),
    "Leaf scorch": (
        "Remove infected leaves and improve airflow. "
        "A labelled fungicide applied early can slow spread."
    ),
    "Leaf mold": (
        "Increase airflow and reduce humidity in the canopy. "
        "Remove infected leaves and use a labelled fungicide."
    ),
    "Septoria leaf spot": (
        "Rotate crops, mulch, and remove lower infected leaves. "
        "Chlorothalonil or copper fungicides are commonly used."
    ),
    "Two-spotted spider mite": (
        "Spray plants with water to knock down mites and encourage predators "
        "like ladybirds. Use insecticidal soap or miticide if severe."
    ),
    "Target spot": (
        "Rotate crops and remove crop debris. "
        "A labelled fungicide applied early can reduce spread."
    ),
    "Yellow leaf curl virus": (
        "There is no cure. Remove infected plants and control whiteflies, "
        "the virus vector, with approved measures."
    ),
    "Mosaic virus": (
        "There is no cure. Remove infected plants, control aphids, and "
        "disinfect tools; use resistant varieties next season."
    ),
}

_HEALTHY_ADVICE = (
    "Your plant looks healthy. Keep watering at the base, maintain spacing "
    "for airflow, and keep monitoring the leaves."
)


@dataclass(frozen=True)
class CropDisease:
    """Human-readable description of a predicted class."""

    label: str
    crop: str
    disease: str
    is_healthy: bool
    advice: str


def describe(label: str) -> CropDisease:
    """Return metadata for a raw class label.

    Unknown labels fall back to a neutral description rather than failing, so
    a model with a different class ordering degrades gracefully.
    """
    info = _CLASS_INFO.get(label)
    if info is None:
        return CropDisease(
            label=label,
            crop="Unknown",
            disease=label.replace("_", " ").strip(),
            is_healthy=False,
            advice=(
                "The model returned an unrecognised label. Ensure the model's "
                "class ordering matches CLASSES in app/ml/labels.py."
            ),
        )
    crop, disease, is_healthy = info
    advice = _HEALTHY_ADVICE if is_healthy else _ADVICE.get(
        disease, "Consult your local agricultural extension officer for advice."
    )
    return CropDisease(
        label=label,
        crop=crop,
        disease=disease,
        is_healthy=is_healthy,
        advice=advice,
    )
