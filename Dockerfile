FROM python:3.11-slim

WORKDIR /app

RUN apt-get update && apt-get install -y curl && rm -rf /var/lib/apt/lists/*

RUN curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
RUN apt-get install -y nodejs

COPY backend/requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY backend/ ./backend/
COPY frontend/ ./frontend/

# Real Centaurion state read by the live dashboard (backend/api/live_data.py resolves
# REPO_ROOT to /app). A read-only snapshot baked at build time — refreshes each deploy.
# Verified secret-free: memory/supermemory.json is an env-ref, not a real key.
COPY memory/ ./memory/
COPY .github/ ./.github/
COPY .planning/ ./.planning/

WORKDIR /app/frontend
RUN npm install && npm run build

WORKDIR /app/backend

# Run as a non-root user (defense in depth). Create appuser, hand it ownership
# of /app, then drop privileges. The app only reads its baked-in state, so a
# non-privileged user is sufficient at runtime.
RUN useradd --create-home --uid 10001 appuser \
    && chown -R appuser:appuser /app
USER appuser

EXPOSE 8000

# Liveness probe — hits the fast, dependency-free health endpoint. curl is
# already installed above. Non-zero exit marks the container unhealthy.
HEALTHCHECK --interval=30s --timeout=5s --start-period=20s --retries=3 \
    CMD curl -fsS http://localhost:8000/api/health || exit 1

CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]
