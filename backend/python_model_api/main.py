from fastapi import FastAPI, File, UploadFile, HTTPException
from fastapi.middleware.cors import CORSMiddleware
import uvicorn
import numpy as np
import cv2
import io
import os
import threading
from model_loader import load_models, preprocess_image
from advanced_detection import check_exif_data, calculate_ela_score

app = FastAPI(title="MesoNet Inference API")

# Enable CORS for Flutter web or separate backend communication
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)

# Global model instances
face_model = None
scene_model = None
models_loaded = False

def _load_models_background():
    """Load models in background thread so health checks pass immediately."""
    global face_model, scene_model, models_loaded
    try:
        print("--- Starting AI Model Initialization (Background Thread) ---")
        face_model, scene_model = load_models()
        models_loaded = True
        print("--- AI Model Initialization Complete ---")
    except Exception as e:
        print(f"CRITICAL: Model loading failed: {e}")

@app.on_event("startup")
def startup_event():
    print("--- FastAPI Server Starting (models will load in background) ---")
    thread = threading.Thread(target=_load_models_background, daemon=True)
    thread.start()

@app.get("/")
def read_root():
    return {"message": "MesoNet Inference API is running", "models_loaded": models_loaded}

@app.post("/predict")
async def predict(file: UploadFile = File(...)):
    global face_model, scene_model
    if not models_loaded or face_model is None or scene_model is None:
        raise HTTPException(status_code=503, detail="Models are still loading, please retry in 30 seconds")

    contents = await file.read()
    filename = file.filename.lower()


    # Determine if it's an image or video
    if filename.endswith(('.png', '.jpg', '.jpeg', '.webp')):
        # Advanced Validation 1: EXIF Metadata Check
        is_suspicious_exif, exif_reason = check_exif_data(contents)
        if is_suspicious_exif:
            print(f"--- REJECTED BY EXIF --- {exif_reason}")
            return {
                "filename": file.filename,
                "prediction": "edited",
                "confidence": 99.0,
                "raw_score": 0.0,
                "note": f"Metadata flag: {exif_reason}"
            }
            
        # Advanced Validation 2: Error Level Analysis
        ela_score = calculate_ela_score(contents)
        print(f"ELA Variance Score: {ela_score}")
        if ela_score > 300.0:  # Threshold for high variance photoshops
            print("--- REJECTED BY ELA --- High compression variance detected")
            return {
                "filename": file.filename,
                "prediction": "edited",
                "confidence": 96.0,
                "raw_score": 0.0,
                "note": "ELA Analysis detected heavy manipulation"
            }

        try:
            img_tensor, face_found = preprocess_image(contents)
            
            if face_found:
                print("--- ROUTING TO FACE MODEL ---")
                prediction = face_model.predict(img_tensor)[0][0]
                used_model = "face_efficientnet"
            else:
                print("--- ROUTING TO SCENE MODEL (CIFAKE) ---")
                prediction = scene_model.predict(img_tensor)[0][0]
                used_model = "scene_cifake"
                
        except Exception as e:
            print(f"DEBUG Error in image: {e}")
            raise HTTPException(status_code=400, detail=f"Error processing image: {str(e)}")
    
    elif filename.endswith(('.mp4', '.avi', '.mov', '.mkv')):
        try:
            # For videos, extract the middle frame
            # Temporary save to read with OpenCV
            temp_path = f"temp_{file.filename}"
            with open(temp_path, "wb") as f:
                f.write(contents)
            
            abs_temp_path = os.path.abspath(temp_path)
            
            try:
                cap = cv2.VideoCapture(abs_temp_path)
                frame_count = int(cap.get(cv2.CAP_PROP_FRAME_COUNT))
                
                # If frame count is zero (missing HEVC codec on Windows), fallback to arbitrary frames
                if frame_count <= 0:
                    frame_count = 30 # arbitrary fallback
                
                # Sample 3 frames: 10%, 50%, 90%
                sample_points = [int(frame_count * 0.1), int(frame_count * 0.5), int(frame_count * 0.9)]
                predictions = []
                model_used_list = []

                for pos in sample_points:
                    cap.set(cv2.CAP_PROP_POS_FRAMES, pos)
                    ret, frame = cap.read()
                    
                    # If absolute position fails (codec issue), just read the next available frame
                    if not ret:
                        ret, frame = cap.read()
                        if not ret:
                            continue
                    
                    # Convert BGR to RGB
                    frame_rgb = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)
                    img_tensor, face_found = preprocess_image(cv2.imencode('.jpg', frame_rgb)[1].tobytes())
                    
                    if face_found:
                        pred = face_model.predict(img_tensor)[0][0]
                        model_used_list.append("face_efficientnet")
                    else:
                        pred = scene_model.predict(img_tensor)[0][0]
                        model_used_list.append("scene_cifake")
                    
                    predictions.append(pred)

                if not predictions:
                    # Provide a neutral prediction if the video simply cannot be decoded by Windows
                    prediction = 0.5  
                    used_model = "bypass_codec_failure"
                else:
                    prediction = float(np.mean(predictions))
                    used_model = f"multi_frame_aggregate ({', '.join(set(model_used_list))})"
                    
            finally:
                if 'cap' in locals():
                    cap.release()
                if os.path.exists(abs_temp_path):
                    try:
                        os.remove(abs_temp_path)
                    except:
                        pass
        except Exception as e:
            print(f"DEBUG Error in video: {e}")
            raise HTTPException(status_code=400, detail=f"Error processing video: {str(e)}")
    
    else:
        raise HTTPException(status_code=400, detail="Unsupported file format")

    print(f"\n--- INFERENCE RESULT ---")
    print(f"Raw Prediction Float: {float(prediction)}")
    
    # MesoNet output: sigmoid (0 to 1)
    # If prediction > threshold, it's 'real'
    # We use 0.4 for images, but an even lower 0.25 for videos because mobile video compression 
    # and motion blur severely impacts frame quality, heavily biasing the CNN towards 'FAKE'.
    is_video = filename.endswith(('.mp4', '.avi', '.mov', '.mkv'))
    threshold = 0.25 if is_video else 0.4
    
    is_real = float(prediction) > threshold
    label = "real" if is_real else "edited"
    confidence = float(prediction) if is_real else 1.0 - float(prediction)

    return {
        "filename": file.filename,
        "prediction": label,
        "confidence": round(confidence * 100, 2),
        "raw_score": float(prediction),
        "ai_model": used_model
    }

if __name__ == "__main__":
    uvicorn.run(app, host="0.0.0.0", port=8005)
