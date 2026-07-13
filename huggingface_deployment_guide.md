# Deploying to Hugging Face Spaces (Python Model API)

Follow these exact steps to host your FastAPI model on Hugging Face Spaces:

### Step 1: Create a Space on Hugging Face
1. Go to [huggingface.co](https://huggingface.co) and sign in.
2. Go to **Spaces** -> **Create new Space**.
3. Choose:
   * **Space SDK:** `Docker`
   * **Docker template:** `Blank`
   * **Hardware:** `CPU basic - 2 vCPU · 16 GB · Free`
   * **Visibility:** `Public` (recommended for easy integration)

### Step 2: Push your code using Git
1. Install Git LFS on your machine if you haven't:
   ```bash
   git lfs install
   ```
2. Clone your Hugging Face space repository locally:
   ```bash
   git clone https://huggingface.co/spaces/YOUR_USERNAME/media-validate-api
   ```
3. Copy the following folders/files from this project into the cloned Hugging Face Space folder:
   * **`backend/`** folder (specifically `backend/python_model_api/` path)
   * **`models/`** folder (specifically the `.keras` files)
   * Copy the **`Dockerfile`** file from the root of this project directly into the root of the Hugging Face space folder.
4. Configure Git LFS for model files:
   ```bash
   git lfs track "*.keras"
   git lfs track "*.pkl"
   ```
5. Add, commit, and push to Hugging Face:
   ```bash
   git add .
   git commit -m "Deploy FastAPI model"
   git push origin main
   ```
   *(Note: Use your Hugging Face username and your generated Access Token (Write permissions) as the password when pushing).*

### Step 3: Connect Choreo Go Backend
Once the build is complete and status is **Running**:
1. Copy the Hugging Face space URL (e.g., `https://YOUR_USERNAME-media-validate-api.hf.space`).
2. Go to your **Choreo Console** for the Go backend service.
3. In **Environment Variables / Configurations**, update the `PYTHON_API_URL` variable to point to your space's endpoint:
   ```env
   PYTHON_API_URL=https://YOUR_USERNAME-media-validate-api.hf.space/predict
   ```
4. Save and redeploy your Go backend.
