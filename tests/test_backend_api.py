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


def test_dashboard_stats_are_live_not_mock():
    """Stats must reflect real on-disk state, not the old 127-op fixture."""
    data = client.get("/api/dashboard/stats").json()
    for key in (
        "total_operations",
        "active_operations",
        "success_rate",
        "system_health",
        "active_pipelines",
        "recent_activity",
    ):
        assert key in data, f"missing {key}"
    assert isinstance(data["total_operations"], int)
    assert 0 <= data["system_health"] <= 100
    assert 0 <= data["success_rate"] <= 100
    assert isinstance(data["recent_activity"], list)


def test_status_live_endpoint():
    resp = client.get("/api/status/live")
    assert resp.status_code == 200
    data = resp.json()
    assert data["source"] == "live"
    assert "dev_loop" in data
    assert isinstance(data["routing_decisions"], int)


def test_cicd_health_is_live():
    resp = client.get("/api/cicd/health")
    assert resp.status_code == 200
    data = resp.json()
    assert "services" in data and isinstance(data["services"], list)
    names = {s["name"] for s in data["services"]}
    assert "Dev Loop" in names  # proves it's the live provider, not mock
