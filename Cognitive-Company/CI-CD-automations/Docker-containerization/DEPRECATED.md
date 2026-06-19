# ⚠️ DEPRECATED — not the production deployment

This directory is a **legacy prototype**: a standalone Python `http.server`
(`main.py`) that renders static marketing/landing pages. It is **not** what
Centaurion deploys to production and is **not** built by CI.

## What actually ships

Production is the **root `Dockerfile`** (a React/Vite frontend served by a
FastAPI backend), deployed to Render via the root `render.yaml`:

- App entrypoint: `backend/main.py` (FastAPI, health at `/api/health`)
- Frontend: `frontend/` (built to `frontend/dist`, served by the backend)
- Deploy config: `render.yaml`
- CI: `.github/workflows/ci.yml` builds and health-checks **that** image.

## Known issues if you try to use this anyway

- `Dockerfile` `CMD` references `Cognitive-Company/CI-CD-automations/Docker-containerization/main.py`,
  but the build context is this leaf directory, so that path does not exist
  inside the image (use `Dockerfile.local`, whose `CMD` is `python main.py`).

Kept for reference only. Do not point Render or CI at this directory.
