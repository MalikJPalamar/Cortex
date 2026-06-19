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

EXPOSE 8000

CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]
