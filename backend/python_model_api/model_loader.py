import tensorflow as tf
import os
import cv2
import numpy as np

# Each model has its own required input resolution
FACE_IMAGE_SIZE  = (224, 224)   # Face model expects 224x224
SCENE_IMAGE_SIZE = (224, 224)   # EfficientNetV2B0 - landscape/artifact model

# Use absolute path detection to find models regardless of where the script is run
BASE_DIR = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
FACE_MODEL_PATH = os.path.join(BASE_DIR, "models", "efficientnet_b4_face_model.keras")
SCENE_MODEL_PATH = os.path.join(BASE_DIR, "models", "artifact_efficientnetv2b0.keras")

# Initialize MTCNN Face Detection
_mtcnn_detector = None
try:
    from mtcnn import MTCNN
    _mtcnn_detector = MTCNN()
    print("MTCNN Face Detector initialized successfully for inference API.")
except Exception as e:
    print(f"Warning: MTCNN initialization failed ({e}). Falling back to Haar Cascades.")

# Initialize multiple cascades for robust face detection (fallback)
cascades = {}
cascade_names = {
    "alt2": "haarcascade_frontalface_alt2.xml",
    "default": "haarcascade_frontalface_default.xml",
    "profile": "haarcascade_profileface.xml"
}

for key, filename in cascade_names.items():
    try:
        path = cv2.data.haarcascades + filename
        cascade = cv2.CascadeClassifier(path)
        if not cascade.empty():
            cascades[key] = cascade
    except Exception as e:
        pass

def load_models():
    """Loads both the Face and ArtiFact Scene models."""
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
        face_model = tf.keras.models.load_model(FACE_MODEL_PATH, compile=False)
        print(f"Face Model (EfficientNetB4, {FACE_IMAGE_SIZE}) loaded from {FACE_MODEL_PATH}")
    else:
        print(f"ERROR: Face Model file not found at {FACE_MODEL_PATH}")
        
    if os.path.exists(SCENE_MODEL_PATH):
        scene_model = tf.keras.models.load_model(SCENE_MODEL_PATH, compile=False)
        print(f"Scene Model (EfficientNetV2B0, {SCENE_IMAGE_SIZE}) loaded from {SCENE_MODEL_PATH}")
    else:
        print(f"ERROR: Scene Model file not found at {SCENE_MODEL_PATH}")
        
    return face_model, scene_model

def preprocess_image(image_bytes, use_face_size=False):
    """Detects face, crops, resizes, and preprocesses.
    
    Args:
        image_bytes: Raw image bytes
        use_face_size: If True, resize to FACE_IMAGE_SIZE (224x224).
                       If False, resize to SCENE_IMAGE_SIZE (224x224).
    Returns:
        (tensor, face_found)
    """
    # Convert bytes to numpy array
    nparr = np.frombuffer(image_bytes, np.uint8)
    img_bgr = cv2.imdecode(nparr, cv2.IMREAD_COLOR)
    if img_bgr is None:
        raise ValueError("Could not decode image bytes")
    
    # Needs to be RGB
    img_rgb = cv2.cvtColor(img_bgr, cv2.COLOR_BGR2RGB)
    
    # 1. Face Extraction
    face_found = False
    crop = None
    h, w, _ = img_rgb.shape
    
    # Try MTCNN first (deep learning-based, highly robust)
    if _mtcnn_detector is not None:
        try:
            results = _mtcnn_detector.detect_faces(img_rgb)
            if results:
                print(f"MTCNN: Found {len(results)} face(s)")
                # Get the first face detection (usually the primary one)
                detection = results[0]
                x, y, box_w, box_h = detection['box']
                
                # Keep within bounds
                xmin = max(0, x)
                ymin = max(0, y)
                box_w = min(box_w, w - xmin)
                box_h = min(box_h, h - ymin)
                
                crop = (xmin, ymin, box_w, box_h)
                face_found = True
        except Exception as e:
            print(f"Warning: MTCNN processing failed ({e}). Trying Haar Cascades...")
            
    # Try OpenCV Haar Cascades if MediaPipe failed or isn't initialized
    if not face_found and cascades:
        # VERY IMPORTANT: Downscale a copy strictly for detection to avoid high-res misses
        scale_ratio = 800.0 / max(h, w)
        if scale_ratio < 1.0:
            small_w = int(w * scale_ratio)
            small_h = int(h * scale_ratio)
            detect_img = cv2.resize(img_rgb, (small_w, small_h))
        else:
            detect_img = img_rgb
            scale_ratio = 1.0

        # Run OpenCV Haar Cascades
        gray = cv2.cvtColor(detect_img, cv2.COLOR_RGB2GRAY)
        
        faces = []
        # Try frontal face alt2 first (highly accurate, fewer false negatives)
        if "alt2" in cascades:
            faces = cascades["alt2"].detectMultiScale(gray, scaleFactor=1.05, minNeighbors=3, minSize=(20, 20))
            
        # Try frontal face default next if no faces found
        if len(faces) == 0 and "default" in cascades:
            faces = cascades["default"].detectMultiScale(gray, scaleFactor=1.05, minNeighbors=3, minSize=(20, 20))
            
        # Try profile face last if still no faces found
        if len(faces) == 0 and "profile" in cascades:
            faces = cascades["profile"].detectMultiScale(gray, scaleFactor=1.05, minNeighbors=3, minSize=(20, 20))

        if len(faces) > 0:
            print(f"OpenCV: Found {len(faces)} face(s)")
            face_found = True
            
            # Grab the largest face by bounding box area
            faces = sorted(faces, key=lambda f: f[2]*f[3], reverse=True)
            x_s, y_s, bw_s, bh_s = faces[0]
            
            # Map back to original resolution
            xmin = int(x_s / scale_ratio)
            ymin = int(y_s / scale_ratio)
            box_w = int(bw_s / scale_ratio)
            box_h = int(bh_s / scale_ratio)
            
            crop = (xmin, ymin, box_w, box_h)

    # Crop the face if found with some padding
    if face_found and crop:
        x, y, bw, bh = crop
        padding = 0.2
        pad_x = int(bw * padding)
        pad_y = int(bh * padding)
        
        xmin_pad = max(0, x - pad_x)
        ymin_pad = max(0, y - pad_y)
        xmax_pad = min(w, x + bw + 2 * pad_x)
        ymax_pad = min(h, y + bh + 2 * pad_y)
        
        cropped_face = img_rgb[ymin_pad:ymax_pad, xmin_pad:xmax_pad]
        if cropped_face.size != 0:
            img_rgb = cropped_face
    
    # 2. Resize to the correct size for the selected model
    target_size = FACE_IMAGE_SIZE if use_face_size else SCENE_IMAGE_SIZE
    img_tensor = tf.convert_to_tensor(img_rgb)
    img_tensor = tf.image.resize(img_tensor, target_size)
    img_tensor = tf.expand_dims(img_tensor, axis=0)
    
    # 3. EfficientNet preprocessing (works for both EfficientNetB4 and EfficientNetV2B0)
    img_tensor = tf.keras.applications.efficientnet.preprocess_input(img_tensor)
    
    return img_tensor, face_found
