import tensorflow as tf
import os
import cv2
import numpy as np

# EfficientNetB0 standard resolution
IMAGE_SIZE = (224, 224)
# Use absolute path detection to find models regardless of where the script is run
BASE_DIR = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
FACE_MODEL_PATH = os.path.join(BASE_DIR, "models", "efficientnet_model.keras")
SCENE_MODEL_PATH = os.path.join(BASE_DIR, "models", "cifake_efficientnet.keras")

try:
    face_cascade = cv2.CascadeClassifier(cv2.data.haarcascades + 'haarcascade_frontalface_default.xml')
except Exception as e:
    face_cascade = None
    print(f"Warning: OpenCV Haar initialization failed ({e}). Full image will be used.")

def load_models():
    """Loads both the Face and CIFAKE Scene models."""
    # FACE_MODEL_PATH and SCENE_MODEL_PATH are already absolute paths (built from BASE_DIR)
    # DO NOT join with dirname(__file__) again - that creates a broken double path
    print(f"BASE_DIR resolved to: {BASE_DIR}")
    print(f"Looking for Face Model at: {FACE_MODEL_PATH}")
    print(f"Looking for Scene Model at: {SCENE_MODEL_PATH}")
    
    # Debug: List what's actually in the models directory
    models_dir = os.path.join(BASE_DIR, "models")
    if os.path.exists(models_dir):
        print(f"Contents of {models_dir}: {os.listdir(models_dir)}")
    else:
        print(f"WARNING: Models directory does not exist: {models_dir}")
        # Try alternative paths inside the container
        for alt in ["/app/models", "/app/backend/python_model_api/models", "/models"]:
            if os.path.exists(alt):
                print(f"FOUND alternative models dir: {alt} -> {os.listdir(alt)}")
    
    face_model = None
    scene_model = None
    
    if os.path.exists(FACE_MODEL_PATH):
        face_model = tf.keras.models.load_model(FACE_MODEL_PATH)
        print(f"Face Model loaded successfully from {FACE_MODEL_PATH}")
    else:
        print(f"ERROR: Face Model file not found at {FACE_MODEL_PATH}")
        
    if os.path.exists(SCENE_MODEL_PATH):
        scene_model = tf.keras.models.load_model(SCENE_MODEL_PATH)
        print(f"CIFAKE Scene Model loaded successfully from {SCENE_MODEL_PATH}")
    else:
        print(f"ERROR: CIFAKE Model file not found at {SCENE_MODEL_PATH}")
        
    return face_model, scene_model

def preprocess_image(image_bytes):
    """Detects face, crops, resizes, and preprocesses. Returns (tensor, face_found)."""
    # Convert bytes to numpy array
    nparr = np.frombuffer(image_bytes, np.uint8)
    img_bgr = cv2.imdecode(nparr, cv2.IMREAD_COLOR)
    
    # Needs to be RGB
    img_rgb = cv2.cvtColor(img_bgr, cv2.COLOR_BGR2RGB)
    
    # 1. Face Extraction
    face_found = False
    
    if face_cascade is not None and not face_cascade.empty():
        h, w, _ = img_rgb.shape
        
        # VERY IMPORTANT: Downscale a copy strictly for detection to avoid high-res misses
        scale_ratio = 800.0 / max(h, w)
        if scale_ratio < 1.0:
            small_w = int(w * scale_ratio)
            small_h = int(h * scale_ratio)
            detect_img = cv2.resize(img_rgb, (small_w, small_h))
        else:
            detect_img = img_rgb
            scale_ratio = 1.0

        # Run OpenCV Haar Cascade
        gray = cv2.cvtColor(detect_img, cv2.COLOR_RGB2GRAY)
        faces = face_cascade.detectMultiScale(gray, scaleFactor=1.1, minNeighbors=4, minSize=(30, 30))

        if len(faces) > 0:
            print(f"OpenCV: Found {len(faces)} face(s)")
            face_found = True
            
            # Grab the largest face by bounding box area
            faces = sorted(faces, key=lambda f: f[2]*f[3], reverse=True)
            x_s, y_s, bw_s, bh_s = faces[0]
            
            # Map back to original ultra-HD resolution
            x = int(x_s / scale_ratio)
            y = int(y_s / scale_ratio)
            bw = int(bw_s / scale_ratio)
            bh = int(bh_s / scale_ratio)
            
            padding = 0.2
            pad_x = int(bw * padding)
            pad_y = int(bh * padding)
            
            xmin = max(0, x - pad_x)
            ymin = max(0, y - pad_y)
            xmax = min(w, x + bw + 2 * pad_x)
            ymax = min(h, y + bh + 2 * pad_y)
            
            cropped_face = img_rgb[ymin:ymax, xmin:xmax]
            if cropped_face.size != 0:
                img_rgb = cropped_face
    
    # 2. Resize and Format for TensorFlow
    img_tensor = tf.convert_to_tensor(img_rgb)
    img_tensor = tf.image.resize(img_tensor, IMAGE_SIZE)
    img_tensor = tf.expand_dims(img_tensor, axis=0)
    
    # 3. EfficientNet preprocessing
    img_tensor = tf.keras.applications.efficientnet.preprocess_input(img_tensor)
    
    return img_tensor, face_found
