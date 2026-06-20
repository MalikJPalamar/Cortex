"""Tests for production hardening: rate limiting, enriched health, readiness,
and structured request logging.

Single-operator hardening — NOT auth. This suite owns the hardening surface and
deliberately does not touch test_backend_api.py. Skipped cleanly if fastapi /
httpx are not installed so it never blocks the lightweight smoke tests.

Run: CENTAURION_LIVE_FETCH=0 /tmp/centv/bin/python -m pytest tests/test_hardening.py -q
"""

import importlib
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


def _fresh_client(monkeypatch, limit):
    """Build a TestClient against a freshly-imported app with the given per-IP
    rate limit. Re-importing rebuilds the middleware stack so each test gets a
    clean limiter (its sliding-window state is per-instance)."""
    monkeypatch.setenv("CENTAURION_RATE_LIMIT_PER_MIN", str(limit))
    # Drop cached modules so the new env value is read when middleware is built.
    for mod in ("main", "observability"):
        sys.modules.pop(mod, None)
    import observability  # noqa: F401
    main = importlib.import_module("main")
    return TestClient(main.app), main


# ---- Rate limiting (anti-abuse, not auth) --------------------------------


def test_rate_limit_returns_429_after_threshold(monkeypatch):
    limit = 3
    client, _ = _fresh_client(monkeypatch, limit)

    # A non-exempt endpoint. First `limit` requests pass, then 429.
    ok = [client.get("/api/dashboard/stats").status_code for _ in range(limit)]
    assert all(code != 429 for code in ok), ok

    blocked = client.get("/api/dashboard/stats")
    assert blocked.status_code == 429
    body = blocked.json()
    assert body["error"] == "rate_limited"
    assert "Retry-After" in blocked.headers


def test_health_is_exempt_from_rate_limit(monkeypatch):
    limit = 2
    client, _ = _fresh_client(monkeypatch, limit)

    # Far exceed the limit on /api/health — keep-warm pings must never throttle.
    for _ in range(limit * 5):
        resp = client.get("/api/health")
        assert resp.status_code == 200
        assert resp.json()["status"] == "healthy"


# ---- Enriched health -----------------------------------------------------


def test_health_includes_uptime_and_version(monkeypatch):
    client, _ = _fresh_client(monkeypatch, 1000)
    body = client.get("/api/health").json()
    assert body["status"] == "healthy"
    assert body["version"]
    assert isinstance(body["uptime_seconds"], (int, float))
    assert body["uptime_seconds"] >= 0


# ---- Readiness probe -----------------------------------------------------


def test_readiness_check_works(monkeypatch, tmp_path):
    client, main = _fresh_client(monkeypatch, 1000)

    # Point both checked paths at existing dirs -> ready (200).
    monkeypatch.setattr(main, "FRONTEND_DIR", str(tmp_path))
    monkeypatch.setattr(main, "STATE_DIR", str(tmp_path))
    resp = client.get("/api/health/ready")
    assert resp.status_code == 200
    body = resp.json()
    assert body["status"] == "ready"
    assert body["checks"]["frontend_dist"] is True
    assert body["checks"]["state_dir"] is True

    # Missing resource -> 503.
    monkeypatch.setattr(main, "FRONTEND_DIR", str(tmp_path / "nope"))
    resp = client.get("/api/health/ready")
    assert resp.status_code == 503
    assert resp.json()["status"] == "not_ready"


# ---- Structured logging middleware does not break responses --------------


def test_logging_middleware_preserves_responses(monkeypatch, caplog):
    import logging

    client, _ = _fresh_client(monkeypatch, 1000)

    with caplog.at_level(logging.INFO, logger="centaurion.access"):
        resp = client.get("/api/health")

    assert resp.status_code == 200
    assert resp.json()["status"] == "healthy"

    # A structured access line was emitted with the expected fields.
    lines = [r.getMessage() for r in caplog.records]
    assert any(
        "method=GET" in line
        and "path=/api/health" in line
        and "status=200" in line
        and "duration_ms=" in line
        for line in lines
    ), lines
