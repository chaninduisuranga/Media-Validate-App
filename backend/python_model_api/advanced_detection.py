"""
advanced_detection.py — Media Forgery Forensics Module

Implements three tiers of forensic analysis:
  1. EXIF + XMP Metadata Deep Analysis
  2. Perceptual Hashing (pHash + dHash)
  3. Video Optical Flow Inter-Frame Forensics
"""

import os
import io
import math
import struct
import hashlib
import datetime
import xml.etree.ElementTree as ET

import numpy as np
import cv2
from PIL import Image
from PIL.ExifTags import TAGS

# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------

SUSPICIOUS_SOFTWARE = [
    "Adobe Photoshop",
    "Midjourney",
    "DALL-E",
    "Stable Diffusion",
    "Canva",
    "GIMP",
    "Lightroom",
    "Firefly",
    "Imagemagick",
    "PicsArt",
    "DALL·E",
    "Leonardo AI",
    "Runway",
    "Kling",
    "Sora",
    "Deepfacelab",
    "FaceSwap",
    "DeepFaceLab",
    "retouch",
]

# Camera lens makes that carry trustworthy EXIF metadata
KNOWN_CAMERA_MAKES = [
    "canon", "nikon", "sony", "fujifilm", "olympus", "panasonic",
    "leica", "pentax", "samsung", "apple", "google", "huawei",
    "xiaomi", "oppo", "vivo", "oneplus",
]

# ============================================================
# 1. EXIF + XMP METADATA DEEP ANALYSIS
# ============================================================

def _extract_xmp_from_bytes(image_bytes: bytes) -> str:
    """
    Raw XMP packet extraction directly from file bytes.
    XMP is stored as UTF-8 text wrapped in <?xpacket ...?> tags.
    Works on JPEG, PNG, WebP without relying on Pillow's XMP support.
    """
    try:
        start_marker = b"<?xpacket begin"
        end_marker   = b"<?xpacket end"
        start_idx = image_bytes.find(start_marker)
        if start_idx == -1:
            return ""
        end_idx = image_bytes.find(end_marker, start_idx)
        if end_idx == -1:
            return ""
        end_idx += 50  # grab the closing tag too
        return image_bytes[start_idx:end_idx].decode("utf-8", errors="replace")
    except Exception:
        return ""


def _parse_xmp_edit_history(xmp_text: str) -> list[dict]:
    """
    Parse xmpMM:History entries from XMP text.
    Returns list of {'action', 'software_agent', 'when'} dicts.
    """
    history = []
    if not xmp_text:
        return history
    try:
        # Strip the xpacket wrapper so ElementTree can parse it
        start = xmp_text.find("<x:xmpmeta")
        end   = xmp_text.find("</x:xmpmeta>")
        if start == -1 or end == -1:
            return history
        xmp_body = xmp_text[start : end + len("</x:xmpmeta>")]

        # Register common XMP namespaces to avoid 'ns0:' prefixes
        ns = {
            "x"     : "adobe:ns:meta/",
            "xmpMM" : "http://ns.adobe.com/xap/1.0/mm/",
            "stEvt" : "http://ns.adobe.com/xap/1.0/sType/ResourceEvent#",
            "rdf"   : "http://www.w3.org/1999/02/22-rdf-syntax-ns#",
        }
        root = ET.fromstring(xmp_body)

        # Find all stEvt:action elements anywhere in the tree
        for elem in root.iter("{http://ns.adobe.com/xap/1.0/sType/ResourceEvent#}action"):
            # Siblings / parent attributes
            parent = elem
            action  = elem.text or ""
            agent   = ""
            when    = ""

            # Walk up to the resource event element for sibling data
            for sibling_tag in [
                "{http://ns.adobe.com/xap/1.0/sType/ResourceEvent#}softwareAgent",
                "{http://ns.adobe.com/xap/1.0/sType/ResourceEvent#}when",
            ]:
                sib = elem.find(f"../{sibling_tag}")  # won't work across all trees
                if sib is not None:
                    if "softwareAgent" in sibling_tag:
                        agent = sib.text or ""
                    elif "when" in sibling_tag:
                        when = sib.text or ""

            history.append({"action": action.strip(), "software_agent": agent.strip(), "when": when.strip()})

        # Fallback: search raw text for softwareAgent patterns
        if not history:
            import re
            agents = re.findall(r'softwareAgent[^>]*>([^<]+)<', xmp_text)
            actions = re.findall(r'stEvt:action[^>]*>([^<]+)<', xmp_text)
            for i, ag in enumerate(agents):
                action_val = actions[i] if i < len(actions) else "unknown"
                history.append({"action": action_val.strip(), "software_agent": ag.strip(), "when": ""})

    except Exception as e:
        print(f"XMP parse error: {e}")
    return history


def check_xmp_history(image_bytes: bytes) -> dict:
    """
    Analyse XMP edit history for manipulation signatures.
    Returns:
        {
            'is_suspicious': bool,
            'confidence_penalty': float,   # 0.0–1.0 penalty added to edited score
            'reason': str,
            'xmp_history': list,
        }
    """
    result = {"is_suspicious": False, "confidence_penalty": 0.0, "reason": "No XMP history found", "xmp_history": []}
    try:
        xmp_text = _extract_xmp_from_bytes(image_bytes)
        if not xmp_text:
            return result

        history = _parse_xmp_edit_history(xmp_text)
        result["xmp_history"] = [h for h in history if h.get("software_agent")]

        for entry in history:
            agent = entry.get("software_agent", "").lower()
            for sus in SUSPICIOUS_SOFTWARE:
                if sus.lower() in agent:
                    result["is_suspicious"]       = True
                    result["confidence_penalty"]  = 0.92
                    result["reason"] = f"XMP edit history shows manipulation software: '{entry['software_agent']}' (action: {entry['action']})"
                    return result

        if len(history) > 3:
            result["is_suspicious"]      = True
            result["confidence_penalty"] = 0.75
            result["reason"] = f"XMP history shows {len(history)} edit operations — heavily processed image"
        elif len(history) > 0:
            result["reason"] = f"XMP history found ({len(history)} operations) — appears standard"

    except Exception as e:
        result["reason"] = f"XMP analysis error: {e}"
    return result


def check_exif_full(image_bytes: bytes) -> dict:
    """
    Deep EXIF analysis:
    - Software tag (existing)
    - Timestamp consistency (OriginalDate vs Digitized vs Modify)
    - Camera make/model presence and plausibility
    - GPS data presence (bonus authenticity signal)
    Returns:
        {
            'is_suspicious': bool,
            'confidence_penalty': float,
            'reason': str,
            'exif_fields': dict,
        }
    """
    result = {
        "is_suspicious": False,
        "confidence_penalty": 0.0,
        "reason": "Standard EXIF data",
        "exif_fields": {},
    }
    try:
        image = Image.open(io.BytesIO(image_bytes))
        exifdata = image.getexif()

        if not exifdata:
            # AI images often have NO exif at all — mild signal
            result["reason"] = "No EXIF data (neutral — could be AI/screenshot/WhatsApp)"
            return result

        fields = {}
        for tag_id, value in exifdata.items():
            tag = TAGS.get(tag_id, str(tag_id))
            fields[tag] = str(value)
        result["exif_fields"] = fields

        # ── Check 1: Software tag ──────────────────────────────────────────
        software = fields.get("Software", "").lower()
        for sus in SUSPICIOUS_SOFTWARE:
            if sus.lower() in software:
                result["is_suspicious"]      = True
                result["confidence_penalty"] = 0.95
                result["reason"] = f"EXIF Software tag reveals editing tool: '{fields.get('Software')}'"
                return result

        # ── Check 2: Timestamp mismatch ────────────────────────────────────
        date_original  = fields.get("DateTimeOriginal", "")
        date_digitized = fields.get("DateTimeDigitized", "")
        date_modified  = fields.get("DateTime", "")

        def parse_exif_dt(s):
            try:
                return datetime.datetime.strptime(s[:19], "%Y:%m:%d %H:%M:%S")
            except Exception:
                return None

        dt_orig = parse_exif_dt(date_original)
        dt_dig  = parse_exif_dt(date_digitized)
        dt_mod  = parse_exif_dt(date_modified)

        if dt_orig and dt_mod:
            delta = abs((dt_mod - dt_orig).total_seconds())
            # More than 48 hours apart → likely re-saved/edited
            if delta > 48 * 3600:
                days = delta / 86400
                result["is_suspicious"]      = True
                result["confidence_penalty"] = 0.65
                result["reason"] = (
                    f"EXIF timestamp mismatch: Original={date_original}, "
                    f"Modified={date_modified} — {days:.1f} days gap suggests re-save after editing"
                )
                return result

        if dt_orig and dt_dig:
            delta = abs((dt_orig - dt_dig).total_seconds())
            # Original and digitized should be identical (or very close)
            if delta > 3600:
                result["is_suspicious"]      = True
                result["confidence_penalty"] = 0.60
                result["reason"] = (
                    f"EXIF DateTimeOriginal vs Digitized mismatch by "
                    f"{delta/3600:.1f}h — possible format conversion"
                )
                return result

        # ── Check 3: Camera make/model plausibility ────────────────────────
        make  = fields.get("Make", "").lower()
        model = fields.get("Model", "")

        # Has model but no make → suspicious
        if model and not make:
            result["is_suspicious"]      = True
            result["confidence_penalty"] = 0.55
            result["reason"] = f"EXIF has Camera Model ('{model}') but no Make — metadata likely tampered"
            return result

        # Has make but it's not a real camera brand → suspicious
        if make and not any(brand in make for brand in KNOWN_CAMERA_MAKES):
            result["is_suspicious"]      = True
            result["confidence_penalty"] = 0.50
            result["reason"] = f"EXIF Make '{fields.get('Make')}' is not a recognised camera/phone brand"
            return result

        # ── All clear ──────────────────────────────────────────────────────
        has_gps = any("GPS" in k for k in fields)
        result["reason"] = (
            f"Clean EXIF — Camera: {fields.get('Make','')} {fields.get('Model','')}"
            + (" | GPS present" if has_gps else "")
        )

    except Exception as e:
        result["reason"] = f"EXIF analysis error: {e}"
    return result


# ============================================================
# 2. PERCEPTUAL HASHING (pHash + dHash)
# ============================================================

def compute_phash(image_bytes: bytes, hash_size: int = 16) -> str | None:
    """
    DCT-based Perceptual Hash (pHash).
    Converts image to grayscale, resizes to (hash_size*4 × hash_size*4),
    applies 2D DCT, keeps top-left (hash_size × hash_size) frequencies,
    then thresholds at mean → binary string → hex.
    """
    try:
        nparr = np.frombuffer(image_bytes, np.uint8)
        img   = cv2.imdecode(nparr, cv2.IMREAD_GRAYSCALE)
        if img is None:
            return None

        # Resize to a larger square for DCT accuracy
        size  = hash_size * 4
        img   = cv2.resize(img, (size, size), interpolation=cv2.INTER_AREA)
        img_f = np.float32(img)

        # Apply 2D DCT row-by-row then column-by-column
        dct_rows = np.apply_along_axis(lambda r: np.fft.rfft(r).real, 1, img_f)
        dct_cols = np.apply_along_axis(lambda c: np.fft.rfft(c).real, 0, dct_rows)

        # Keep low-frequency component (top-left square)
        low_freq = dct_cols[:hash_size, :hash_size]

        mean_val = low_freq.mean()
        bits = (low_freq > mean_val).flatten()

        # Pack bits into hex string
        hash_hex = ""
        for i in range(0, len(bits), 8):
            byte = 0
            for j, bit in enumerate(bits[i : i + 8]):
                byte |= (int(bit) << j)
            hash_hex += format(byte, "02x")

        return hash_hex

    except Exception as e:
        print(f"pHash error: {e}")
        return None


def compute_dhash(image_bytes: bytes, hash_size: int = 16) -> str | None:
    """
    Difference Hash (dHash).
    Compares adjacent pixel brightness — fast and robust to slight edits.
    """
    try:
        nparr = np.frombuffer(image_bytes, np.uint8)
        img   = cv2.imdecode(nparr, cv2.IMREAD_GRAYSCALE)
        if img is None:
            return None

        img    = cv2.resize(img, (hash_size + 1, hash_size), interpolation=cv2.INTER_AREA)
        diff   = img[:, 1:] > img[:, :-1]   # compare adjacent columns
        bits   = diff.flatten()

        hash_hex = ""
        for i in range(0, len(bits), 8):
            byte = 0
            for j, bit in enumerate(bits[i : i + 8]):
                byte |= (int(bit) << j)
            hash_hex += format(byte, "02x")

        return hash_hex

    except Exception as e:
        print(f"dHash error: {e}")
        return None


def hamming_distance(hash1: str, hash2: str) -> int:
    """Bit-level Hamming distance between two hex hash strings."""
    if len(hash1) != len(hash2):
        return 9999
    distance = 0
    for c1, c2 in zip(hash1, hash2):
        xor = int(c1, 16) ^ int(c2, 16)
        distance += bin(xor).count("1")
    return distance


def check_phash_against_known(image_bytes: bytes, known_hashes: list[str] | None = None) -> dict:
    """
    Compute pHash and dHash for the image.
    Optionally compare against a list of known-bad hashes.

    Returns:
        {
            'phash': str,
            'dhash': str,
            'is_known_fake': bool,
            'matched_hash': str | None,
            'hamming_dist': int | None,
            'reason': str,
        }
    """
    result = {
        "phash"       : None,
        "dhash"       : None,
        "is_known_fake": False,
        "matched_hash": None,
        "hamming_dist": None,
        "reason"      : "Perceptual hash computed",
    }
    try:
        ph = compute_phash(image_bytes)
        dh = compute_dhash(image_bytes)
        result["phash"] = ph
        result["dhash"] = dh

        if ph is None and dh is None:
            result["reason"] = "Could not compute perceptual hash"
            return result

        if known_hashes:
            best_dist  = 9999
            best_match = None
            for kh in known_hashes:
                if len(kh) == len(ph or ""):
                    d = hamming_distance(ph, kh)
                    if d < best_dist:
                        best_dist  = d
                        best_match = kh

            result["hamming_dist"] = best_dist
            result["matched_hash"] = best_match

            THRESHOLD = 10  # ≤10 bit difference → near-identical image
            if best_dist <= THRESHOLD:
                result["is_known_fake"] = True
                result["reason"] = (
                    f"pHash matches known fake image (Hamming distance={best_dist} ≤ {THRESHOLD})"
                )
            else:
                result["reason"] = f"No match in known-fake database (closest distance={best_dist})"

    except Exception as e:
        result["reason"] = f"pHash analysis error: {e}"
    return result


# ============================================================
# 3. VIDEO OPTICAL FLOW INTER-FRAME FORENSICS
# ============================================================

def _resize_for_flow(frame: np.ndarray, max_dim: int = 480) -> np.ndarray:
    """Scale frame down for fast optical flow computation."""
    h, w = frame.shape[:2]
    if max(h, w) <= max_dim:
        return frame
    scale = max_dim / float(max(h, w))
    return cv2.resize(frame, (int(w * scale), int(h * scale)), interpolation=cv2.INTER_AREA)


def analyze_video_optical_flow(video_bytes: bytes, temp_dir: str = "/tmp") -> dict:
    """
    Inter-frame Forensics via Optical Flow:

    1. Dense optical flow (Farneback) between consecutive sampled frames.
    2. Magnitude variance — deepfakes have unnatural flow discontinuities at
       face boundaries causing locally high variance spikes.
    3. Frame difference histogram analysis — abrupt scene cuts indicate spliced video.
    4. Brightness consistency — deepfake overlays often flicker in luminance.

    Returns:
        {
            'is_suspicious': bool,
            'confidence_penalty': float,
            'reason': str,
            'flow_variance_mean': float,
            'flow_variance_max': float,
            'brightness_std_mean': float,
            'abrupt_cuts': int,
            'frames_analyzed': int,
        }
    """
    result = {
        "is_suspicious"      : False,
        "confidence_penalty" : 0.0,
        "reason"             : "Video optical flow analysis skipped",
        "flow_variance_mean" : 0.0,
        "flow_variance_max"  : 0.0,
        "brightness_std_mean": 0.0,
        "abrupt_cuts"        : 0,
        "frames_analyzed"    : 0,
    }

    import tempfile, os

    tmp_path = None
    cap      = None
    try:
        # Write to a temp file because OpenCV needs a file path
        with tempfile.NamedTemporaryFile(delete=False, suffix=".mp4", dir=temp_dir) as tmp:
            tmp.write(video_bytes)
            tmp_path = tmp.name

        cap = cv2.VideoCapture(tmp_path)
        if not cap.isOpened():
            result["reason"] = "Could not open video for optical flow analysis"
            return result

        total_frames = int(cap.get(cv2.CAP_PROP_FRAME_COUNT))
        fps          = cap.get(cv2.CAP_PROP_FPS) or 25

        # Sample at most 30 frames spread evenly across the video
        MAX_SAMPLES = 30
        if total_frames <= 0:
            total_frames = int(MAX_SAMPLES * fps)   # fallback for codec-broken count

        step         = max(1, total_frames // MAX_SAMPLES)
        sample_pts   = list(range(0, total_frames, step))[:MAX_SAMPLES]

        frames_gray   = []
        brightness_vals = []

        for pt in sample_pts:
            cap.set(cv2.CAP_PROP_POS_FRAMES, pt)
            ret, frame = cap.read()
            if not ret:
                ret, frame = cap.read()
            if not ret:
                continue

            small  = _resize_for_flow(frame)
            gray   = cv2.cvtColor(small, cv2.COLOR_BGR2GRAY)
            frames_gray.append(gray)
            brightness_vals.append(float(np.mean(gray)))

        result["frames_analyzed"] = len(frames_gray)
        if len(frames_gray) < 3:
            result["reason"] = "Not enough decodable frames for optical flow analysis"
            return result

        # ── A. Optical flow variance ───────────────────────────────────────
        flow_variances  = []
        frame_diffs     = []
        abrupt_cuts     = 0
        ABRUPT_THRESHOLD = 40.0  # mean absolute pixel diff → scene cut

        for i in range(1, len(frames_gray)):
            prev = frames_gray[i - 1]
            curr = frames_gray[i]

            # Farneback dense optical flow
            flow = cv2.calcOpticalFlowFarneback(
                prev, curr, None,
                pyr_scale=0.5, levels=3, winsize=15,
                iterations=3, poly_n=5, poly_sigma=1.2,
                flags=0,
            )

            # Magnitude of flow vectors
            mag, _ = cv2.cartToPolar(flow[..., 0], flow[..., 1])
            flow_variances.append(float(np.var(mag)))

            # Frame absolute difference for cut detection
            diff_score = float(np.mean(cv2.absdiff(prev, curr)))
            frame_diffs.append(diff_score)
            if diff_score > ABRUPT_THRESHOLD:
                abrupt_cuts += 1

        flow_var_mean = float(np.mean(flow_variances)) if flow_variances else 0.0
        flow_var_max  = float(np.max(flow_variances))  if flow_variances else 0.0

        # ── B. Brightness consistency ──────────────────────────────────────
        brightness_std = float(np.std(brightness_vals)) if brightness_vals else 0.0

        result["flow_variance_mean"]  = round(flow_var_mean, 4)
        result["flow_variance_max"]   = round(flow_var_max,  4)
        result["brightness_std_mean"] = round(brightness_std, 4)
        result["abrupt_cuts"]         = abrupt_cuts

        # ── C. Decision rules ──────────────────────────────────────────────
        flags   = []
        penalty = 0.0

        # Rule 1: Excessively high flow variance spikes → unnatural motion discontinuities
        #         Deepfake face overlays create sharp flow inconsistencies at boundaries.
        if flow_var_max > 800:
            flags.append(f"Extreme optical flow variance spike (max={flow_var_max:.1f}) — face boundary artefacts")
            penalty = max(penalty, 0.70)

        elif flow_var_mean > 200:
            flags.append(f"High mean optical flow variance ({flow_var_mean:.1f}) — unnatural motion patterns")
            penalty = max(penalty, 0.55)

        # Rule 2: Multiple abrupt cuts without matching audio/scene change → spliced video
        if abrupt_cuts >= 3:
            flags.append(f"{abrupt_cuts} abrupt scene cuts detected — possible video splicing")
            penalty = max(penalty, 0.60)

        # Rule 3: High brightness flickering — deepfake temporal inconsistency
        if brightness_std > 25:
            flags.append(f"Luminance flickering (std={brightness_std:.1f}) — temporal inconsistency")
            penalty = max(penalty, 0.50)

        if flags:
            result["is_suspicious"]      = True
            result["confidence_penalty"] = penalty
            result["reason"]             = " | ".join(flags)
        else:
            result["reason"] = (
                f"Video forensics clean — flow_var_mean={flow_var_mean:.2f}, "
                f"brightness_std={brightness_std:.2f}, abrupt_cuts={abrupt_cuts}"
            )

    except Exception as e:
        import traceback
        result["reason"] = f"Optical flow analysis error: {e}"
        print(f"Optical flow error:\n{traceback.format_exc()}")
    finally:
        if cap is not None:
            try:
                cap.release()
            except Exception:
                pass
        if tmp_path and os.path.exists(tmp_path):
            try:
                os.remove(tmp_path)
            except Exception:
                pass

    return result


# ============================================================
# 4. ORIGINAL HELPERS (preserved for backward compat)
# ============================================================

def check_exif_data(image_bytes: bytes):
    """
    Legacy wrapper — returns (is_suspicious: bool, reason: str).
    Now delegates to the full check_exif_full() implementation.
    """
    r = check_exif_full(image_bytes)
    return r["is_suspicious"], r["reason"]


def calculate_ela_score(image_bytes: bytes, quality: int = 90) -> float:
    """
    Error Level Analysis (ELA).
    Resaves image at known JPEG quality and measures compression variance.
    High variance → likely copy-paste manipulation.
    """
    try:
        nparr    = np.frombuffer(image_bytes, np.uint8)
        original = cv2.imdecode(nparr, cv2.IMREAD_COLOR)
        if original is None:
            return 0.0

        h, w = original.shape[:2]
        if max(h, w) > 1280:
            scale    = 1280.0 / max(h, w)
            original = cv2.resize(original, (int(w * scale), int(h * scale)), interpolation=cv2.INTER_AREA)

        encode_param = [int(cv2.IMWRITE_JPEG_QUALITY), quality]
        ok, encimg   = cv2.imencode(".jpg", original, encode_param)
        if not ok:
            return 0.0

        resaved = cv2.imdecode(encimg, cv2.IMREAD_COLOR)
        if resaved is None:
            return 0.0

        diff  = cv2.absdiff(original, resaved)
        score = float(np.var(diff))
        return score

    except Exception as e:
        print(f"ELA calculation error: {e}")
        return 0.0
