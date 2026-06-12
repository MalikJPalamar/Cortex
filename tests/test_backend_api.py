"""API tests for the Centaurion FastAPI backend.

Exercises the actual product surface (the web dashboard's backend). Requires
fastapi + httpx; the suite is skipped cleanly if those are not installed so it
never blocks the lightweight smoke tests.
"""

import sys
from pathlib import Path

import pytest

pytest.importorskip("fastapi")
pytest.importorskip("httpx")

from fastapi.testclient import TestClient  # noqa: E402

REPO_ROOT = Path(__file__).resolve().parent.parent
BACKEND_DIR = REPO_ROOT / "backend"

# The backend uses package-relative imports (`from api.routes import ...`),
# which assume `backend/` is on the path.
sys.path.insert(0, str(BACKEND_DIR))

from main import app  # noqa: E402

client = TestClient(app)


def test_health_endpoint():
    resp = client.get("/api/health")
    assert resp.status_code == 200
    assert resp.json()["status"] == "healthy"


def test_dashboard_stats_endpoint():
    resp = client.get("/api/dashboard/stats")
    assert resp.status_code == 200
    assert isinstance(resp.json(), dict)
