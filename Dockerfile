# Use Python 3.12 slim for a smaller image size
FROM python:3.12-slim

# Set environment variables
ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1
ENV PORT=7860
ENV HOME=/home/user

# Create a non-root user with UID 1000 (Hugging Face default)
RUN useradd -m -u 1000 user

# Set work directory
WORKDIR /app

# Install system dependencies (OpenCV needs libGL and glib to process images/videos)
RUN apt-get update && apt-get install -y \
    libgl1 \
    libglib2.0-0 \
    && rm -rf /var/lib/apt/lists/*

# Install python dependencies
COPY --chown=user:user backend/python_model_api/requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt huggingface_hub

# Create models directory
RUN mkdir -p /app/models && chown user:user /app/models

# Copy python API application code
COPY --chown=user:user ./backend/python_model_api /app/backend/python_model_api

# Copy model download startup script
COPY --chown=user:user download_models.py /app/download_models.py

# Expose the default Hugging Face port
EXPOSE 7860

# Switch to the non-root user for security
USER user

# Set working directory to the API directory
WORKDIR /app/backend/python_model_api

# Run: download models first, then start the FastAPI server
CMD ["sh", "-c", "python /app/download_models.py && python main.py"]
