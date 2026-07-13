import nbformat
import json
import os

NOTEBOOK_PATH = r"d:\Media Validate App\notebooks\03_efficientnet_model.ipynb"

def patch_notebook():
    with open(NOTEBOOK_PATH, 'r', encoding='utf-8') as f:
        nb = nbformat.read(f, as_version=4)

    # 1. Update IMAGE_SIZE and BATCH_SIZE
    for cell in nb.cells:
        if cell.cell_type == 'code':
            if 'IMAGE_SIZE   = (128, 128)' in cell.source:
                cell.source = cell.source.replace('IMAGE_SIZE   = (128, 128)', 'IMAGE_SIZE   = (224, 224)')
            if 'BATCH_SIZE   = 16' in cell.source:
                cell.source = cell.source.replace('BATCH_SIZE   = 16', 'BATCH_SIZE   = 8') 

            # 2. Inject Data Augmentation into the model builder cell
            if 'base_model = EfficientNetB0(' in cell.source:
                # Update base_model instantiation shape mapping
                cell.source = cell.source.replace('input_shape=(128, 128, 3)', 'input_shape=(IMAGE_SIZE[0], IMAGE_SIZE[1], 3)')
                cell.source = cell.source.replace('shape=(128, 128, 3)', 'shape=(IMAGE_SIZE[0], IMAGE_SIZE[1], 3)')
                
                augmentation_code = """
# Advanced Data Augmentation to prevent Overfitting to original dataset
data_augmentation = tf.keras.Sequential([
    layers.RandomFlip("horizontal"),
    layers.RandomRotation(0.1),
    layers.RandomZoom(0.15),
    layers.RandomBrightness(0.3),
    layers.RandomContrast(0.2),
], name="data_augmentation")

x = data_augmentation(inputs)
x = base_model(x, training=False)   # training=False keeps BatchNorm frozen
"""
                # Do not inject if already injected
                if 'data_augmentation' not in cell.source:
                    cell.source = cell.source.replace('x       = base_model(inputs, training=False)   # training=False keeps BatchNorm frozen', augmentation_code)
                
                print("Injected Data Augmentation and applied dynamic IMAGE_SIZE mapping.")

    # Save
    with open(NOTEBOOK_PATH, 'w', encoding='utf-8') as f:
        nbformat.write(nb, f)
        
    print("Notebook perfectly updated for Augmented 224x224 training.")

if __name__ == "__main__":
    patch_notebook()
