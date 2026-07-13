---
title: Media Validate API
emoji: 🔍
colorFrom: blue
colorTo: purple
sdk: docker
pinned: false
license: mit
---

# Media Validate API

FastAPI backend for AI-powered media authenticity detection.

## Models
- **Face Model**: EfficientNetB4 trained on 140k face images
- **Landscape Model**: EfficientNetV2B0 trained on CIFAKE dataset

## Endpoints
- `GET /` - API status
- `GET /ready` - Readiness check (returns 503 until models loaded)
- `POST /predict` - Upload image/video for authenticity prediction
