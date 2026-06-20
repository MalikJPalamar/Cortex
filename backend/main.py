from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import FileResponse, JSONResponse
from api.routes import router
from security import SecurityHeadersMiddleware, get_allowed_origins
from observability import RateLimitMiddleware, RequestLoggingMiddleware
import os
import time

APP_VERSION = "1.0.0"

# Captured at import time so /api/health can report process uptime cheaply,
# without touching any external dependency.
_START_TIME = time.monotonic()

app = FastAPI(
    title="Centaurion",
    description="AI-Driven Cognitive Operating System",
    version=APP_VERSION
)

FRONTEND_DIR = "/app/frontend/dist"
# State dir baked into the image (Dockerfile COPY memory/). The readiness probe
# confirms the live-data backing files are present before declaring ready.
STATE_DIR = "/app/memory"

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

# Anti-abuse per-IP rate limiter (NOT auth). Exempts /api/health so keep-warm
# pings are never throttled. Limit is env-configurable.
app.add_middleware(RateLimitMiddleware)

# Structured one-line-per-request access log to stdout (Render captures it).
# Added last so it is the outermost middleware and times the full request.
app.add_middleware(RequestLoggingMiddleware)

app.include_router(router, prefix="/api")

@app.get("/api/health")
async def health_check():
    # Fast, dependency-free. Reports process uptime + version for observability.
    return {
        "status": "healthy",
        "version": APP_VERSION,
        "uptime_seconds": round(time.monotonic() - _START_TIME, 2),
    }

@app.get("/api/health/ready")
async def readiness_check():
    # Confirms the served frontend bundle and state dir are present. Returns 503
    # when a backing resource is missing so orchestration can hold traffic.
    checks = {
        "frontend_dist": os.path.isdir(FRONTEND_DIR),
        "state_dir": os.path.isdir(STATE_DIR),
    }
    ready = all(checks.values())
    return JSONResponse(
        status_code=200 if ready else 503,
        content={"status": "ready" if ready else "not_ready", "checks": checks},
    )

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
