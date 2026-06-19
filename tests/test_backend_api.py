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


# The old mock fixture ids — their absence proves we serve real data now.
_MOCK_OP_IDS = {"op-001", "op-002", "op-003", "op-004", "op-005"}
_MOCK_PIPE_IDS = {"pipe-001", "pipe-002", "pipe-003", "pipe-004"}


def test_ai_operations_are_live_not_mock():
    resp = client.get("/api/ai-operations")
    assert resp.status_code == 200
    data = resp.json()
    assert "operations" in data and isinstance(data["operations"], list)
    assert data["total"] == len(data["operations"])
    assert data["operations"], "live ops derive from routing log + dev loop"
    for op in data["operations"]:
        for key in ("id", "name", "type", "status", "created_at"):
            assert key in op, f"operation missing {key}"
    ids = {op["id"] for op in data["operations"]}
    assert ids.isdisjoint(_MOCK_OP_IDS), "must not return old mock operation ids"
    # The dev-loop run is surfaced as a real operation.
    assert any(op["type"] == "dev_loop" for op in data["operations"])


def test_cicd_pipelines_are_live_not_mock():
    resp = client.get("/api/cicd/pipelines")
    assert resp.status_code == 200
    data = resp.json()
    assert "pipelines" in data and isinstance(data["pipelines"], list)
    assert data["total"] == len(data["pipelines"])
    assert data["pipelines"], "live pipelines come from .github/workflows/*"
    for p in data["pipelines"]:
        for key in ("id", "name", "status", "branch"):
            assert key in p, f"pipeline missing {key}"
        assert p["branch"] == "main"
        assert p["status"] == "configured"
    ids = {p["id"] for p in data["pipelines"]}
    assert ids.isdisjoint(_MOCK_PIPE_IDS), "must not return old mock pipeline ids"


def test_settings_are_live_not_mock():
    import json

    resp = client.get("/api/settings")
    assert resp.status_code == 200
    data = resp.json()
    assert isinstance(data, dict)
    # Real config shape: identity + memory, not the old api_keys/notifications mock.
    assert "identity" in data and "memory" in data
    assert "api_keys" not in data, "must not return old mock settings shape"
    assert data["identity"]["service"] == "Centaurion"
    assert data["identity"]["version"] == "1.0.0"
    assert data["memory"]["service"] == "supermemory"
    # Never surface a raw secret value — only a boolean configured flag.
    assert isinstance(data["memory"]["api_key_configured"], bool)
    serialized = json.dumps(data)
    assert "${" not in serialized, "no env-ref placeholders leaked"
    assert "SUPERMEMORY_API_KEY" not in serialized
