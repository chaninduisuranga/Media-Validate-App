"""
Download models from HuggingFace Hub at container startup.
Models are stored in the 'models' folder of the HF Space repo itself.
"""
import os
from huggingface_hub import hf_hub_download

REPO_ID = "Chanindu01/media-validate-api"
MODELS_DIR = "/app/models"

MODELS = [
    "efficientnet_b4_face_model.keras",
    "artifact_efficientnetv2b0.keras",
]

os.makedirs(MODELS_DIR, exist_ok=True)

for model_filename in MODELS:
    dest_path = os.path.join(MODELS_DIR, model_filename)
    if os.path.exists(dest_path):
        print(f"[download_models] Already exists, skipping: {model_filename}")
        continue

    print(f"[download_models] Downloading {model_filename} from {REPO_ID}...")
    try:
        downloaded_path = hf_hub_download(
            repo_id=REPO_ID,
            filename=f"models/{model_filename}",
            repo_type="space",
            local_dir=MODELS_DIR,
            local_dir_use_symlinks=False,
        )
        # hf_hub_download saves to local_dir/filename structure, move to flat models dir
        expected = os.path.join(MODELS_DIR, "models", model_filename)
        if os.path.exists(expected) and not os.path.exists(dest_path):
            os.rename(expected, dest_path)
        print(f"[download_models] ✅ Downloaded: {model_filename} -> {dest_path}")
    except Exception as e:
        print(f"[download_models] ❌ Failed to download {model_filename}: {e}")
        raise SystemExit(1)

print("[download_models] ✅ All models ready.")
