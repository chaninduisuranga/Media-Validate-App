import os
import glob
import cv2
import numpy as np
from PIL import Image
from sklearn.model_selection import train_test_split
from tqdm import tqdm
import logging
import uuid
from concurrent.futures import ProcessPoolExecutor
import multiprocessing

# Setup logging
logging.basicConfig(level=logging.INFO, format='%(levelname)s: %(message)s')

# Constants
RAW_DATA_DIR = os.path.join("data", "raw")
PROCESSED_DATA_DIR = os.path.join("data", "processed", "images")
TARGET_SIZE = (224, 224)
SUPPORTED_EXTENSIONS = ('*.jpg', '*.jpeg', '*.png', '*.webp', '*.bmp')

# Global detector for lazy initialization in worker processes
_detector = None

# Robust Face Detection Initialization
def initialize_face_detector():
    """Tries to initialize MediaPipe, falls back to OpenCV Haar Cascades."""
    # 1. Try MediaPipe (Legacy Solutions)
    try:
        import mediapipe as mp
        detector = mp.solutions.face_detection.FaceDetection(model_selection=1, min_detection_confidence=0.5)
        logging.info("Using MediaPipe (Solutions API) for face detection.")
        return ("mediapipe", detector)
    except (ImportError, AttributeError):
        pass

    # 2. Try OpenCV Haar Cascade (Universal Fallback)
    try:
        cascade_path = cv2.data.haarcascades + 'haarcascade_frontalface_default.xml'
        detector = cv2.CascadeClassifier(cascade_path)
        if not detector.empty():
            logging.info("Using OpenCV Haar Cascade for face detection.")
            return ("opencv", detector)
    except Exception:
        pass

    logging.warning("No face detector available. Will process full images only.")
    return ("none", None)

def get_detector():
    global _detector
    if _detector is None:
        _detector = initialize_face_detector()
    return _detector

def get_image_files(directory):
    """Retrieve all supported image files in a directory (recursive, deduplicated)."""
    files = set()
    for ext in SUPPORTED_EXTENSIONS:
        # On Windows, glob is case-insensitive, but we use a set to be safe
        files.update(glob.glob(os.path.join(directory, "**", ext), recursive=True))
        files.update(glob.glob(os.path.join(directory, "**", ext.upper()), recursive=True))
    return sorted(list(files))

def process_image(img_path, detector_tuple, padding=0.2):
    """Reads, processes (face crop or keep full), and resizes the image."""
    detector_type, detector = detector_tuple
    
    img = cv2.imread(img_path)
    if img is None:
        return None
        
    img_rgb = cv2.cvtColor(img, cv2.COLOR_BGR2RGB)
    h, w, _ = img_rgb.shape
    crop = None

    # Detect faces based on type
    if detector_type == "mediapipe" and detector:
        results = detector.process(img_rgb)
        if results.detections:
            detection = results.detections[0] 
            bboxC = detection.location_data.relative_bounding_box
            xmin = int(bboxC.xmin * w)
            ymin = int(bboxC.ymin * h)
            box_w = int(bboxC.width * w)
            box_h = int(bboxC.height * h)
            crop = (xmin, ymin, box_w, box_h)
            
    elif detector_type == "opencv" and detector:
        # Haar Cascades work better on grayscale
        gray = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)
        faces = detector.detectMultiScale(gray, scaleFactor=1.1, minNeighbors=5, minSize=(30, 30))
        if len(faces) > 0:
            # Pick the largest face area
            faces = sorted(faces, key=lambda f: f[2] * f[3], reverse=True)
            crop = faces[0]  # (x, y, w, h)

    # If face found -> apply padding and crop
    if crop:
        x, y, bw, bh = crop
        pad_x = int(bw * padding)
        pad_y = int(bh * padding)
        
        xmin = max(0, x - pad_x)
        ymin = max(0, y - pad_y)
        xmax = min(w, x + bw + 2 * pad_x)
        ymax = min(h, y + bh + 2 * pad_y)
        
        processed_img = img_rgb[ymin:ymax, xmin:xmax]
        if processed_img.size == 0:
            processed_img = img_rgb
    else:
        processed_img = img_rgb
        
    # Final resize to (224, 224)
    processed_img = cv2.resize(processed_img, TARGET_SIZE, interpolation=cv2.INTER_AREA)
    return processed_img

def save_image(img_array, save_path):
    """Saves numpy array as an image file."""
    img_pil = Image.fromarray(img_array)
    img_pil.save(save_path, "JPEG", quality=95)

def process_single_image(args):
    """Worker function for parallel processing."""
    path, save_dir, padding = args
    detector_tuple = get_detector()
    proc_img = process_image(path, detector_tuple, padding)
    if proc_img is not None:
        fname = os.path.splitext(os.path.basename(path))[0]
        unique_name = f"{fname}_{uuid.uuid4().hex[:6]}.jpg"
        save_image(proc_img, os.path.join(save_dir, unique_name))
        return True
    return False

def create_directory_structure():
    """Returns a dictionary of output paths and auto-creates them."""
    splits = ['train', 'val', 'test']
    labels = ['real', 'fake']
    paths = {}
    for split in splits:
        paths[split] = {}
        for label in labels:
            path = os.path.join(PROCESSED_DATA_DIR, split, label)
            os.makedirs(path, exist_ok=True)
            paths[split][label] = path
    return paths

def main():
    logging.info("Starting optimized preprocessing pipeline...")
    dir_paths = create_directory_structure()
    num_workers = multiprocessing.cpu_count()
    logging.info(f"Using {num_workers} parallel workers.")
    
    for label in ['real', 'fake']:
        raw_target_dir = os.path.join(RAW_DATA_DIR, f"{label}_images")
        if not os.path.exists(raw_target_dir):
            logging.warning(f"Directory not found: {raw_target_dir}. Skipping label '{label}'.")
            continue
            
        img_files = get_image_files(raw_target_dir)
        if not img_files:
            logging.warning(f"No valid images found in {raw_target_dir}.")
            continue
        
        logging.info(f"Scanning and splitting {len(img_files)} images for label '{label}'...")
        
        # Split data
        train_paths, temp_paths = train_test_split(img_files, test_size=0.30, random_state=42)
        val_paths, test_paths = train_test_split(temp_paths, test_size=0.50, random_state=42)
        
        mapping = [('train', train_paths), ('val', val_paths), ('test', test_paths)]
        
        for split_inner, paths_inner in mapping:
            save_dir = dir_paths[split_inner][label]
            tasks = [(path, save_dir, 0.2) for path in paths_inner]
            
            with ProcessPoolExecutor(max_workers=num_workers) as executor:
                list(tqdm(
                    executor.map(process_single_image, tasks),
                    total=len(tasks),
                    desc=f"Processing {split_inner} ({label})"
                ))
        
        logging.info(f"Split Summary for '{label}': Train={len(train_paths)}, Val={len(val_paths)}, Test={len(test_paths)}")

    logging.info("Preprocessing complete.")

if __name__ == "__main__":
    main()
