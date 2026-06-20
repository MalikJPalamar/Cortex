from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import FileResponse
from api.routes import router
from security import SecurityHeadersMiddleware, get_allowed_origins
import os

app = FastAPI(
    title="Centaurion",
    description="AI-Driven Cognitive Operating System",
    version="1.0.0"
)

FRONTEND_DIR = "/app/frontend/dist"

# Single-operator dashboard, served same-origin. CORS is an explicit allowlist
# (env-driven via CENTAURION_ALLOWED_ORIGINS) — never a wildcard, which is both
# invalid and unsafe when combined with credentials. No auth/tenancy is added.
app.add_middleware(
    CORSMiddleware,
    allow_origins=get_allowed_origins(),
    allow_credentials=True,
    allow_methods=["GET", "POST", "PUT", "OPTIONS"],
    allow_headers=["Authorization", "Content-Type"],
)

# Defensive security headers on every response (nosniff, frame deny, CSP, ...).
app.add_middleware(SecurityHeadersMiddleware)

app.include_router(router, prefix="/api")

@app.get("/api/health")
async def health_check():
    return {"status": "healthy", "version": "1.0.0"}

@app.get("/")
async def serve_index():
    return FileResponse(os.path.join(FRONTEND_DIR, "index.html"))

@app.get("/{full_path:path}")
async def serve_static(full_path: str):
    file_path = os.path.join(FRONTEND_DIR, full_path)
    if os.path.isfile(file_path):
        return FileResponse(file_path)
    return FileResponse(os.path.join(FRONTEND_DIR, "index.html"))

if __name__ == "__main__":
    import uvicorn
    port = int(os.environ.get("PORT", 8000))
    # Binding all interfaces is required for the app to be reachable inside its
    # container (Render/Docker); not a public-network exposure decision.
    uvicorn.run(app, host="0.0.0.0", port=port)  # nosec B104
