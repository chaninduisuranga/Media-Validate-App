from fastapi import FastAPI, File, UploadFile, HTTPException
from fastapi.middleware.cors import CORSMiddleware
import uvicorn
import numpy as np
import cv2
import os
import sys
import traceback
print("DEBUG cv2 path:", getattr(cv2, "__file__", "no __file__"))
try:
    cv2_init_path = getattr(cv2, "__file__", "")
    # Try loading native module directly to check for shared library errors
    import importlib.machinery
    import importlib.util
    cv2_dir = os.path.dirname(cv2_init_path)
    so_file = os.path.join(cv2_dir, "cv2.abi3.so")
    if os.path.exists(so_file):
        print(f"DEBUG cv2.abi3.so exists, attempting direct load...")
        loader = importlib.machinery.ExtensionFileLoader("cv2", so_file)
        spec = importlib.util.spec_from_loader("cv2", loader)
        native_module = importlib.util.module_from_spec(spec)
        loader.exec_module(native_module)
        print("DEBUG native cv2 load SUCCESS! attributes:", dir(native_module)[:10])
except Exception as e:
    print("DEBUG cv2 diagnostic failed:")
    traceback.print_exc()
import io
import os
import threading
import gc
import psutil
import traceback

# FORCE CPU MODE - Save RAM and initialization time
os.environ["CUDA_VISIBLE_DEVICES"] = "-1"
os.environ["TF_CPP_MIN_LOG_LEVEL"] = "3"
import tensorflow as tf

from model_loader import load_models, preprocess_image
from advanced_detection import (
    check_exif_data,
    check_exif_full,
    check_xmp_history,
    check_phash_against_known,
    analyze_video_optical_flow,
    calculate_ela_score,
)

app = FastAPI(title="Media Validater Inference API")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)

# ---------------------------------------------------------------------------
# Global model instances
# ---------------------------------------------------------------------------
face_model   = None
scene_model  = None
models_loaded = False


def _load_models_background():
    """Load models in background thread so health checks pass immediately."""
    global face_model, scene_model, models_loaded
    try:
        process  = psutil.Process(os.getpid())
        mem_init = process.memory_info().rss / 1024 / 1024
        print(f"--- Starting AI Model Initialization | Initial RAM: {mem_init:.2f}MB ---")

        face_model, scene_model = load_models()
        models_loaded = True

        mem_final = process.memory_info().rss / 1024 / 1024
        print(f"--- AI Models Ready | Total RAM: {mem_final:.2f}MB ---")
        gc.collect()
    except Exception as e:
        print(f"CRITICAL: Model loading failed: {e}")


@app.on_event("startup")
def startup_event():
    print("--- FastAPI Server Starting (models load in background) ---")
    thread = threading.Thread(target=_load_models_background, daemon=True)
    thread.start()


# ---------------------------------------------------------------------------
# Health endpoints
# ---------------------------------------------------------------------------

@app.get("/")
def read_root():
    return {"message": "Media Validater API is running", "models_loaded": models_loaded}


@app.get("/ready")
def readiness_check():
    if not models_loaded or face_model is None or scene_model is None:
        raise HTTPException(status_code=503, detail="Models are still loading")
    return {"status": "ready", "models_loaded": True}


@app.get("/predict")
def predict_info():
    return {
        "message"      : "POST /predict with multipart field 'file'",
        "models_loaded": models_loaded,
    }


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def _weighted_final_score(ai_score: float, forensic_penalty: float) -> float:
    """
    Combine the AI model's raw 'realness' score with forensic penalty.

    ai_score       : 0.0 = definitely fake / 1.0 = definitely real  (from model)
    forensic_penalty: 0.0 = no concern   / 1.0 = confirmed edited  (from forensics)

    The penalty *pulls* the AI score toward 0 (fake).
    Weight: AI model  = 60 %,  Forensic evidence = 40 %
    """
    FORENSIC_WEIGHT = 0.40
    AI_WEIGHT       = 0.60
    # Invert penalty so it represents a 'fake score', then blend
    penalty_as_fake = forensic_penalty                      # 0=clean, 1=dirty
    ai_as_fake      = 1.0 - ai_score                       # 0=real, 1=fake
    combined_fake   = AI_WEIGHT * ai_as_fake + FORENSIC_WEIGHT * penalty_as_fake
    return 1.0 - combined_fake                             # back to realness score


# ---------------------------------------------------------------------------
# /predict  endpoint
# ---------------------------------------------------------------------------

@app.post("/predict")
def predict(file: UploadFile = File(...)):
    global face_model, scene_model

    if not models_loaded or face_model is None or scene_model is None:
        raise HTTPException(status_code=503, detail="Models still loading — retry in 30 seconds")

    contents = file.file.read()
    filename = file.filename.lower()
    size_kb  = len(contents) / 1024
    print(f"\n{'='*60}")
    print(f"--- File: {filename} | {size_kb:.1f} KB ---")

    MAX_BYTES = 10 * 1024 * 1024  # 10 MB
    if len(contents) > MAX_BYTES:
        raise HTTPException(
            status_code=413,
            detail=f"File too large ({size_kb:.0f} KB). Max 10 MB.",
        )

    is_image = filename.endswith((".png", ".jpg", ".jpeg", ".webp"))
    is_video = filename.endswith((".mp4", ".avi", ".mov", ".mkv"))

    # ─────────────────────────────────────────────────────────
    # IMAGE PIPELINE
    # ─────────────────────────────────────────────────────────
    if is_image:

        # ── Forensic Layer 1: Deep EXIF analysis ─────────────
        exif_result = check_exif_full(contents)
        print(f"[EXIF]  suspicious={exif_result['is_suspicious']} | {exif_result['reason'][:80]}")

        if exif_result["is_suspicious"] and exif_result["confidence_penalty"] >= 0.90:
            return {
                "filename"  : file.filename,
                "prediction": "edited",
                "confidence": round(exif_result["confidence_penalty"] * 100, 1),
                "raw_score" : 0.0,
                "ai_model"  : "forensic_exif_hardreject",
                "forensic_detail": exif_result["reason"],
                "forensic_flags": ["exif_manipulation"],
            }

        # ── Forensic Layer 2: XMP Edit History ───────────────
        xmp_result = check_xmp_history(contents)
        print(f"[XMP]   suspicious={xmp_result['is_suspicious']} | {xmp_result['reason'][:80]}")

        if xmp_result["is_suspicious"] and xmp_result["confidence_penalty"] >= 0.90:
            return {
                "filename"  : file.filename,
                "prediction": "edited",
                "confidence": round(xmp_result["confidence_penalty"] * 100, 1),
                "raw_score" : 0.0,
                "ai_model"  : "forensic_xmp_hardreject",
                "forensic_detail": xmp_result["reason"],
                "forensic_flags": ["xmp_edit_history"],
            }

        # ── Forensic Layer 3: Error Level Analysis ───────────
        ela_score = calculate_ela_score(contents)
        print(f"[ELA]   score={ela_score:.2f}")

        if ela_score > 300.0:
            return {
                "filename"  : file.filename,
                "prediction": "edited",
                "confidence": 96.0,
                "raw_score" : 0.0,
                "ai_model"  : "forensic_ela_hardreject",
                "forensic_detail": f"ELA variance {ela_score:.1f} — heavy manipulation detected",
                "forensic_flags": ["ela_manipulation"],
            }

        # ── Forensic Layer 4: Perceptual Hash ────────────────
        phash_result = check_phash_against_known(contents)
        print(f"[pHash] phash={phash_result['phash']} | {phash_result['reason'][:60]}")

        # Accumulate forensic penalty from non-hard-reject checks
        forensic_penalty = 0.0
        forensic_flags   = []

        if exif_result["is_suspicious"]:
            forensic_penalty = max(forensic_penalty, exif_result["confidence_penalty"])
            forensic_flags.append("exif_timestamp_mismatch")

        if xmp_result["is_suspicious"]:
            forensic_penalty = max(forensic_penalty, xmp_result["confidence_penalty"])
            forensic_flags.append("xmp_edit_history")

        if phash_result["is_known_fake"]:
            forensic_penalty = max(forensic_penalty, 0.88)
            forensic_flags.append("phash_known_fake")

        # ela score: scale 0→300 linearly to 0→0.5 penalty
        ela_penalty = min(0.50, ela_score / 600.0)
        forensic_penalty = max(forensic_penalty, ela_penalty)
        if ela_penalty > 0.15:
            forensic_flags.append(f"ela_variance_{ela_score:.0f}")

        # ── AI Model Inference ────────────────────────────────
        try:
            print("--- Routing to AI model ---")
            _, face_found = preprocess_image(contents, use_face_size=False)

            if face_found:
                print("--- DUAL MODEL RUN (Face + Scene) ---")
                # Run Face Model (deepfake / face-swap check)
                face_tensor, _ = preprocess_image(contents, use_face_size=True)
                face_pred = float(face_model.predict(face_tensor)[0][0])

                # Run Scene Model (AI generated / GAN / Diffusion check)
                scene_tensor, _ = preprocess_image(contents, use_face_size=False)
                scene_pred = float(scene_model.predict(scene_tensor)[0][0])

                # Combined score: if either model detects fake, we go with the lowest score
                raw_ai = min(face_pred, scene_pred)
                used_model = f"dual_inference (face: {face_pred:.2f}, scene: {scene_pred:.2f})"
                print(f"[AI] Face Pred: {face_pred:.4f} | Scene Pred: {scene_pred:.4f} | Combined: {raw_ai:.4f}")
            else:
                print("--- SCENE MODEL (224×224) ---")
                img_tensor, _ = preprocess_image(contents, use_face_size=False)
                raw_ai = float(scene_model.predict(img_tensor)[0][0])
                used_model = "scene_artifact_efficientnetv2b0"

            print(f"[AI]    raw={raw_ai:.4f} | forensic_penalty={forensic_penalty:.2f}")

        except Exception as e:
            tb = traceback.format_exc()
            print(f"ERROR in AI inference:\n{tb}")
            raise HTTPException(status_code=400, detail=f"AI inference failed: {e}")

        # ── Combine AI + Forensics ────────────────────────────
        final_score = _weighted_final_score(raw_ai, forensic_penalty)
        print(f"[FINAL] combined_score={final_score:.4f}")

        THRESHOLD = 0.40
        is_real   = final_score > THRESHOLD
        label     = "real" if is_real else "edited"
        confidence = final_score if is_real else 1.0 - final_score

        forensic_summary = (
            f"EXIF: {exif_result['reason'][:50]} | "
            f"XMP: {xmp_result['reason'][:50]} | "
            f"ELA: {ela_score:.1f} | "
            f"pHash: {phash_result['reason'][:40]}"
        )

        return {
            "filename"        : file.filename,
            "prediction"      : label,
            "confidence"      : round(confidence * 100, 2),
            "raw_score"       : round(final_score, 4),
            "ai_raw_score"    : round(raw_ai, 4),
            "forensic_penalty": round(forensic_penalty, 4),
            "ai_model"        : used_model,
            "forensic_flags"  : forensic_flags,
            "forensic_detail" : forensic_summary,
            "phash"           : phash_result.get("phash"),
        }

    # ─────────────────────────────────────────────────────────
    # VIDEO PIPELINE
    # ─────────────────────────────────────────────────────────
    elif is_video:
        temp_path    = None
        cap          = None
        forensic_flags   = []
        forensic_penalty = 0.0

        try:
            # ── Forensic Layer: Optical Flow analysis ────────
            print("--- Running optical flow forensics ---")
            flow_result = analyze_video_optical_flow(contents)
            print(
                f"[FLOW]  suspicious={flow_result['is_suspicious']} | "
                f"cuts={flow_result['abrupt_cuts']} | "
                f"var_max={flow_result['flow_variance_max']} | "
                f"{flow_result['reason'][:60]}"
            )

            if flow_result["is_suspicious"]:
                forensic_penalty = max(forensic_penalty, flow_result["confidence_penalty"])
                forensic_flags.append(f"optical_flow_anomaly")

                # Hard reject only if extremely high penalty
                if flow_result["confidence_penalty"] >= 0.90:
                    return {
                        "filename"       : file.filename,
                        "prediction"     : "edited",
                        "confidence"     : round(flow_result["confidence_penalty"] * 100, 1),
                        "raw_score"      : 0.0,
                        "ai_model"       : "forensic_optflow_hardreject",
                        "forensic_detail": flow_result["reason"],
                        "forensic_flags" : forensic_flags,
                    }

            # ── AI Frame Sampling ─────────────────────────────
            import tempfile
            with tempfile.NamedTemporaryFile(delete=False, suffix=".mp4") as tmp:
                tmp.write(contents)
                temp_path = tmp.name

            abs_path    = os.path.abspath(temp_path)
            cap         = cv2.VideoCapture(abs_path)
            frame_count = int(cap.get(cv2.CAP_PROP_FRAME_COUNT))

            if frame_count <= 0:
                frame_count = 30

            # Sample 5 frames: 10 %, 30 %, 50 %, 70 %, 90 %
            sample_pts = [int(frame_count * p) for p in (0.10, 0.30, 0.50, 0.70, 0.90)]
            predictions  = []
            model_used_list = []

            for pos in sample_pts:
                cap.set(cv2.CAP_PROP_POS_FRAMES, pos)
                ret, frame = cap.read()
                if not ret:
                    ret, frame = cap.read()
                if not ret:
                    continue

                frame_rgb  = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)
                fbytes     = cv2.imencode(".jpg", frame_rgb)[1].tobytes()

                _, face_found = preprocess_image(fbytes, use_face_size=False)
                if face_found:
                    # Run Face Model (deepfake / face-swap check)
                    face_tensor, _ = preprocess_image(fbytes, use_face_size=True)
                    face_pred = float(face_model.predict(face_tensor)[0][0])

                    # Run Scene Model (AI generated / GAN / Diffusion check)
                    scene_tensor, _ = preprocess_image(fbytes, use_face_size=False)
                    scene_pred = float(scene_model.predict(scene_tensor)[0][0])

                    pred = min(face_pred, scene_pred)
                    model_used_list.append(f"dual_frame (face: {face_pred:.2f}, scene: {scene_pred:.2f})")
                else:
                    img_tensor, _ = preprocess_image(fbytes, use_face_size=False)
                    pred = float(scene_model.predict(img_tensor)[0][0])
                    model_used_list.append("scene_artifact_efficientnetv2b0")

                predictions.append(pred)

            if not predictions:
                raw_ai     = 0.5
                used_model = "bypass_codec_failure"
            else:
                raw_ai     = float(np.mean(predictions))
                used_model = f"multi_frame ({', '.join(set(model_used_list))})"

            print(f"[AI-VIDEO] raw={raw_ai:.4f} | forensic_penalty={forensic_penalty:.2f}")

            # ── Combine ───────────────────────────────────────
            final_score = _weighted_final_score(raw_ai, forensic_penalty)
            print(f"[FINAL-VIDEO] combined={final_score:.4f}")

            # Videos use lower threshold (compression hurts quality)
            THRESHOLD_VID = 0.25
            is_real        = final_score > THRESHOLD_VID
            label          = "real" if is_real else "edited"
            confidence     = final_score if is_real else 1.0 - final_score

            return {
                "filename"        : file.filename,
                "prediction"      : label,
                "confidence"      : round(confidence * 100, 2),
                "raw_score"       : round(final_score, 4),
                "ai_raw_score"    : round(raw_ai, 4),
                "forensic_penalty": round(forensic_penalty, 4),
                "ai_model"        : used_model,
                "forensic_flags"  : forensic_flags,
                "forensic_detail" : flow_result["reason"],
                "flow_stats"      : {
                    "frames_analyzed"    : flow_result["frames_analyzed"],
                    "flow_variance_mean" : flow_result["flow_variance_mean"],
                    "flow_variance_max"  : flow_result["flow_variance_max"],
                    "brightness_std"     : flow_result["brightness_std_mean"],
                    "abrupt_cuts"        : flow_result["abrupt_cuts"],
                },
            }

        except Exception as e:
            tb = traceback.format_exc()
            print(f"ERROR in video processing:\n{tb}")
            raise HTTPException(status_code=400, detail=f"Video processing error: {e}")
        finally:
            if cap is not None:
                try:
                    cap.release()
                except Exception:
                    pass
            if temp_path and os.path.exists(temp_path):
                try:
                    os.remove(temp_path)
                except Exception:
                    pass

    else:
        raise HTTPException(status_code=400, detail="Unsupported file format")


if __name__ == "__main__":
    port = int(os.environ.get("PORT", 8085))
    uvicorn.run(app, host="0.0.0.0", port=port)
