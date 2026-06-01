import os
import json
import numpy as np
import tensorflow as tf
from tensorflow.keras.models import load_model
from sklearn.metrics import accuracy_score, precision_score, recall_score, f1_score, roc_auc_score
import pandas as pd
from tqdm import tqdm

# 1. Configuration
BASE_DIR = os.path.join("data", "processed", "images", "test")
MODELS_DIR = "models"
IMAGE_SIZE = (128, 128)
BATCH_SIZE = 32

# Map models to their specific paths and preprocessing needs
MODEL_REGISTRY = {
    "CNN": {
        "path": os.path.join(MODELS_DIR, "cnn_model_fast.keras"),
        "preprocess": "rescale" # Uses 1./255 internal rescaling layer
    },
    "MesoNet": {
        "path": os.path.join(MODELS_DIR, "mesonet_model.keras"),
        "preprocess": "rescale" # Uses 1./255 internal rescaling layer
    },
    "EfficientNet": {
        "path": os.path.join(MODELS_DIR, "efficientnet_model.keras"),
        "preprocess": "efficientnet"
    },
    "Xception": {
        "path": os.path.join(MODELS_DIR, "xception_model.keras"),
        "preprocess": "xception"
    },
    "ResNet50": {
        "path": os.path.join(MODELS_DIR, "resnet50_model.keras"),
        "preprocess": "resnet"
    }
}

def get_preprocess_fn(model_type):
    if model_type == "efficientnet":
        return tf.keras.applications.efficientnet.preprocess_input
    elif model_type == "xception":
        return tf.keras.applications.xception.preprocess_input
    elif model_type == "resnet":
        return tf.keras.applications.resnet50.preprocess_input
    else:
        # For CNN and MesoNet, rescaling is built into the model architecture
        return lambda x: x

def evaluate_models():
    print(f"Loading test dataset from: {BASE_DIR}")
    
    # Load dataset labels once for evaluation
    test_ds_raw = tf.keras.utils.image_dataset_from_directory(
        BASE_DIR,
        image_size=IMAGE_SIZE,
        batch_size=BATCH_SIZE,
        shuffle=False, # Important: Keep order for y_true comparison
        label_mode='binary'
    )
    
    y_true = np.concatenate([y for x, y in test_ds_raw], axis=0).flatten()
    results = {}

    for name, config in MODEL_REGISTRY.items():
        if not os.path.exists(config["path"]):
            print(f"Skipping {name}: File not found at {config['path']}")
            continue
            
        print(f"\n--- Evaluating {name} ---")
        try:
            # Custom objects might be needed if they were used in training
            # For these models, standard load_model usually works
            model = load_model(config["path"])
            
            # Apply preprocessing
            preprocess_fn = get_preprocess_fn(config["preprocess"])
            test_ds = test_ds_raw.map(lambda x, y: (preprocess_fn(x), y)).prefetch(tf.data.AUTOTUNE)
            
            # Predict
            y_pred_prob = model.predict(test_ds).flatten()
            y_pred = (y_pred_prob > 0.5).astype(int)
            
            # Calculate metrics
            metrics = {
                "Accuracy": round(float(accuracy_score(y_true, y_pred)), 4),
                "Precision": round(float(precision_score(y_true, y_pred)), 4),
                "Recall": round(float(recall_score(y_true, y_pred)), 4),
                "F1_Score": round(float(f1_score(y_true, y_pred)), 4),
                "AUC_ROC": round(float(roc_auc_score(y_true, y_pred_prob)), 4)
            }
            
            results[name] = metrics
            print(metrics)
            
        except Exception as e:
            print(f"Error evaluating {name}: {e}")

    # Output Final Results
    if results:
        df = pd.DataFrame(results).T
        print("\nSummary Results:")
        print(df)
        
        # 1. Save to JSON for downstream comparison
        results_file_json = os.path.join(MODELS_DIR, "evaluation_results.json")
        with open(results_file_json, 'w') as f:
            json.dump(results, f, indent=4)
        
        # 2. Save to CSV for spreadsheet tools
        results_file_csv = os.path.join(MODELS_DIR, "evaluation_results.csv")
        df.to_csv(results_file_csv, index_label="Model")
        
        # 3. Save to Markdown for documentation
        results_file_md = os.path.join(MODELS_DIR, "evaluation_results.md")
        with open(results_file_md, 'w') as f:
            f.write("# Model Evaluation Summary\n\n")
            f.write(df.to_markdown())
            f.write("\n")
            
        print(f"\nEvaluation results saved to:")
        print(f"- {results_file_json}")
        print(f"- {results_file_csv}")
        print(f"- {results_file_md}")

if __name__ == "__main__":
    evaluate_models()
