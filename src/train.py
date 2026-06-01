import os
import tensorflow as tf
from tensorflow.keras import layers, models, callbacks
import matplotlib.pyplot as plt
import pickle
import gc

# 1. Device Optimization
# Explicitly disable GPU usage for CPU environments to avoid driver overhead/fragmentation
gpus = tf.config.list_physical_devices('GPU')
if not gpus:
    print("No GPU detected. Enforcing CPU-specific optimizations.")
    tf.config.set_visible_devices([], 'GPU')
else:
    print(f"GPU(s) detected: {gpus}. Enabling hardware acceleration.")
    # For modern GPUs, mixed precision can save memory
    from tensorflow.keras import mixed_precision
    mixed_precision.set_global_policy('mixed_float16')

# 2. Paths
BASE_DIR = os.path.join("..", "data", "processed", "images") if os.path.basename(os.getcwd()) == "src" else os.path.join("data", "processed", "images")
MODEL_SAVE_PATH = os.path.join("..", "models", "cnn_model_v2.keras") if os.path.basename(os.getcwd()) == "src" else os.path.join("models", "cnn_model_v2.keras")
CHECKPOINT_DIR = os.path.join("..", "models", "checkpoints") if os.path.basename(os.getcwd()) == "src" else os.path.join("models", "checkpoints")
os.makedirs(CHECKPOINT_DIR, exist_ok=True)

# 3. Hyperparameters (Optimized for CPU/RAM)
IMAGE_SIZE = (224, 224)
BATCH_SIZE = 16  # Reduced from 64 to prevent RAM-related crashes
EPOCHS = 20

# 4. Data Loading
def load_datasets():
    print("Loading datasets...")
    train_ds = tf.keras.utils.image_dataset_from_directory(
        os.path.join(BASE_DIR, 'train'),
        image_size=IMAGE_SIZE,
        batch_size=BATCH_SIZE,
        label_mode='binary'
    )

    val_ds = tf.keras.utils.image_dataset_from_directory(
        os.path.join(BASE_DIR, 'val'),
        image_size=IMAGE_SIZE,
        batch_size=BATCH_SIZE,
        label_mode='binary'
    )

    # Performance Optimization for CPU
    AUTOTUNE = tf.data.AUTOTUNE
    
    # We avoid .cache() in RAM for 100k images if RAM represents a bottleneck.
    # Instead, we use prefetch buffer to keep the pipeline occupied.
    train_ds = train_ds.shuffle(1000).prefetch(buffer_size=AUTOTUNE)
    val_ds = val_ds.prefetch(buffer_size=AUTOTUNE)
    
    return train_ds, val_ds

# 5. Model Architecture
def build_model():
    model = models.Sequential([
        layers.Rescaling(1./255, input_shape=(224, 224, 3)),
        
        layers.Conv2D(32, (3, 3), activation='relu'),
        layers.MaxPooling2D((2, 2)),
        
        layers.Conv2D(64, (3, 3), activation='relu'),
        layers.MaxPooling2D((2, 2)),
        
        layers.Conv2D(128, (3, 3), activation='relu'),
        layers.MaxPooling2D((2, 2)),
        
        layers.Flatten(),
        layers.Dense(128, activation='relu'),
        layers.Dropout(0.5),
        layers.Dense(1, activation='sigmoid')
    ])

    model.compile(
        optimizer='adam',
        loss='binary_crossentropy',
        metrics=['accuracy']
    )
    return model

# 6. Training with Callbacks
def train():
    train_ds, val_ds = load_datasets()
    model = build_model()
    model.summary()

    # Optimized Callbacks
    early_stop = callbacks.EarlyStopping(
        monitor='val_loss', 
        patience=5, 
        restore_best_weights=True
    )

    checkpoint = callbacks.ModelCheckpoint(
        filepath=os.path.join(CHECKPOINT_DIR, "cnn_epoch_{epoch:02d}.keras"),
        save_best_only=True,
        monitor='val_loss',
        verbose=1
    )

    reduce_lr = callbacks.ReduceLROnPlateau(
        monitor='val_loss',
        factor=0.2,
        patience=2,
        min_lr=1e-6,
        verbose=1
    )

    # Garbage collection before training
    gc.collect()

    print("Starting training...")
    history = model.fit(
        train_ds,
        validation_data=val_ds,
        epochs=EPOCHS,
        callbacks=[early_stop, checkpoint, reduce_lr]
    )

    # Save final model
    model.save(MODEL_SAVE_PATH)
    print(f"Final model saved to {MODEL_SAVE_PATH}")
    
    return history

if __name__ == "__main__":
    train()
