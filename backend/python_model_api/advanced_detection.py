import os
from PIL import Image
from PIL.ExifTags import TAGS
import cv2
import numpy as np
import io

# Common EXIF signatures that indicate manipulation or AI generation
SUSPICIOUS_SOFTWARE = [
    "Adobe Photoshop", 
    "Midjourney", 
    "DALL-E", 
    "Stable Diffusion", 
    "Canva",
    "GIMP",
    "Lightroom"
]

def check_exif_data(image_bytes):
    """
    Reads EXIF metadata to check for known image manipulation software.
    Returns (is_suspicious_bool, reason_string)
    """
    try:
        image = Image.open(io.BytesIO(image_bytes))
        exifdata = image.getexif()
        
        if not exifdata:
            return False, "No EXIF data found (Neutral)"

        for tag_id, data in exifdata.items():
            tag = TAGS.get(tag_id, tag_id)
            if tag == "Software":
                software_str = str(data).lower()
                for sus in SUSPICIOUS_SOFTWARE:
                    if sus.lower() in software_str:
                        return True, f"Found suspicious software signature: {data}"
                        
        return False, "Standard EXIF data"
    except Exception as e:
        print(f"EXIF extraction error: {e}")
        return False, "Error reading EXIF"

def calculate_ela_score(image_bytes, quality=90):
    """
    Performs Error Level Analysis (ELA).
    1. Resaves the image at a known JPEG quality.
    2. Calculates the absolute difference between original and resaved.
    3. Calculates a variance score. High scores often mean parts of the image 
       were stitched/edited together from different sources.
    Returns (float_score)
    """
    try:
        # Load original image
        nparr = np.frombuffer(image_bytes, np.uint8)
        original = cv2.imdecode(nparr, cv2.IMREAD_COLOR)
        if original is None:
            return 0.0

        h, w = original.shape[:2]
        max_dim = 1280
        if max(h, w) > max_dim:
            scale = max_dim / float(max(h, w))
            original = cv2.resize(
                original,
                (int(w * scale), int(h * scale)),
                interpolation=cv2.INTER_AREA,
            )

        # Resave as JPEG in memory at specific quality
        encode_param = [int(cv2.IMWRITE_JPEG_QUALITY), quality]
        ok, encimg = cv2.imencode('.jpg', original, encode_param)
        if not ok:
            return 0.0
        resaved = cv2.imdecode(encimg, cv2.IMREAD_COLOR)
        if resaved is None:
            return 0.0

        # Calculate absolute difference
        diff = cv2.absdiff(original, resaved)
        
        # Calculate score (variance of the difference)
        # High variance means the image has wildly different compression levels (likely copy/pasted)
        score = np.var(diff)
        return float(score)
        
    except Exception as e:
        print(f"ELA calculation error: {e}")
        return 0.0
