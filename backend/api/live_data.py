"""Live data provider — reads REAL Centaurion state instead of mock fixtures.

PT-4: the state files (routing-log, ratings, dev-loop status) are baked into the
Render image at build time, so they would otherwise FREEZE until the next deploy.
The dev loop, however, pushes fresh state to GitHub `main` 3×/day. So each reader
first tries to fetch the file from GitHub raw (cached with a short TTL), and falls
back to the baked-in local copy on any failure. Net effect: the dashboard reflects
new routing decisions without a redeploy, yet never 500s if the network is down or
a file is missing/malformed.

Toggle the live fetch with env CENTAURION_LIVE_FETCH=0 (defaults on). Source repo/
branch are overridable via CENTAURION_RAW_BASE.
"""
import glob
import json
import os
import time
import urllib.request
from datetime import datetime, timezone

# backend/api/live_data.py -> repo root is two levels up. Overridable for tests.
_HERE = os.path.dirname(os.path.abspath(__file__))
REPO_ROOT = os.environ.get(
    "CENTAURION_REPO", os.path.abspath(os.path.join(_HERE, "..", ".."))
)

# Runtime fetch of fresh state from GitHub raw (dev loop pushes to main 3×/day).
_LIVE_FETCH = os.environ.get("CENTAURION_LIVE_FETCH", "1") != "0"
_RAW_BASE = os.environ.get(
    "CENTAURION_RAW_BASE",
    "https://raw.githubusercontent.com/MalikJPalamar/Cortex/main",
)
_FETCH_TTL = int(os.environ.get("CENTAURION_FETCH_TTL", "120"))  # seconds
_FETCH_TIMEOUT = float(os.environ.get("CENTAURION_FETCH_TIMEOUT", "4"))
# Only these committed-state paths are fetched live; everything else stays local.
_LIVE_PATHS = {
    "memory/state/routing-log.jsonl",
    "memory/state/ratings.jsonl",
    "memory/state/dev-loop-status.json",
}
_cache: dict = {}  # rel -> (expires_epoch, text|None)


def _path(rel: str) -> str:
    return os.path.join(REPO_ROOT, rel)


def _fetch_raw(rel: str):
    """Best-effort fetch of a file's text from GitHub raw, TTL-cached.

    Returns the file text, or None if live fetch is disabled, the path isn't a
    live path, or the request fails — callers then fall back to the local copy.
    """
    if not _LIVE_FETCH or rel not in _LIVE_PATHS:
        return None
    now = time.time()
    cached = _cache.get(rel)
    if cached and cached[0] > now:
        return cached[1]
    text = None
    try:
        req = urllib.request.Request(
            f"{_RAW_BASE}/{rel}", headers={"User-Agent": "centaurion-dashboard"}
        )
        with urllib.request.urlopen(req, timeout=_FETCH_TIMEOUT) as resp:
            if resp.status == 200:
                text = resp.read().decode("utf-8")
    except Exception:
        text = None  # network error, 404, timeout — fall back to local
    _cache[rel] = (now + _FETCH_TTL, text)
    return text


def _read_text(rel: str):
    """Fresh text from GitHub raw if available, else the baked-in local file."""
    remote = _fetch_raw(rel)
    if remote is not None:
        return remote
    p = _path(rel)
    if os.path.isfile(p):
        try:
            with open(p, encoding="utf-8") as fh:
                return fh.read()
        except OSError:
            return None
    return None


def _read_jsonl(rel: str) -> list:
    """Read a .jsonl file into a list of dicts, skipping blanks/bad lines."""
    rows = []
    text = _read_text(rel)
    if text:
        for line in text.splitlines():
            line = line.strip()
            if not line:
                continue
            try:
                rows.append(json.loads(line))
            except json.JSONDecodeError:
                continue
    return rows


def _read_json(rel: str) -> dict:
    text = _read_text(rel)
    if text:
        try:
            return json.loads(text)
        except json.JSONDecodeError:
            return {}
    return {}


def _routing_entries() -> list:
    """Real routing decisions (skip the _schema/meta header line)."""
    return [r for r in _read_jsonl("memory/state/routing-log.jsonl") if "timestamp" in r]


def _rating_entries() -> list:
    return [r for r in _read_jsonl("memory/state/ratings.jsonl") if "rating" in r]


def _ago(iso: str) -> str:
    """Best-effort 'Xm/h/d ago' from an ISO-8601 timestamp."""
    if not iso:
        return "unknown"
    try:
        ts = datetime.fromisoformat(iso.replace("Z", "+00:00"))
    except ValueError:
        return iso
    delta = datetime.now(timezone.utc) - ts
    secs = int(delta.total_seconds())
    if secs < 0:
        return "just now"
    if secs < 3600:
        return f"{max(1, secs // 60)}m ago"
    if secs < 86400:
        return f"{secs // 3600}h ago"
    return f"{secs // 86400}d ago"


def get_dashboard_stats() -> dict:
    routing = _routing_entries()
    ratings = _rating_entries()
    devloop = _read_json("memory/state/dev-loop-status.json")

    scores = [r["rating"] for r in ratings if isinstance(r.get("rating"), (int, float))]
    success_rate = round(sum(scores) / len(scores) / 5 * 100, 1) if scores else 0.0

    # system_health: composite of (a) routing correctness over decisions that actually
    # recorded an outcome — NOT penalizing entries that never logged routing_correct —
    # and (b) the task success rate. Falls back gracefully when one signal is absent.
    recorded = [r for r in routing if isinstance(r.get("routing_correct"), bool)]
    routing_health = (
        round(sum(1 for r in recorded if r["routing_correct"]) / len(recorded) * 100)
        if recorded
        else None
    )
    if routing_health is not None and scores:
        system_health = round((routing_health + success_rate) / 2)
    elif routing_health is not None:
        system_health = routing_health
    elif scores:
        system_health = round(success_rate)
    else:
        system_health = 100

    active = 1 if str(devloop.get("status", "")).lower() in {
        "progressing", "running", "in_progress", "active"
    } else 0

    pipelines = glob.glob(_path(".github/workflows/*.yml")) + glob.glob(
        _path(".github/workflows/*.yaml")
    )

    # recent_activity: latest routing decisions, newest first.
    recent = []
    for r in sorted(routing, key=lambda x: x.get("timestamp", ""), reverse=True)[:3]:
        task = (r.get("task") or "").split(" — ")[0].split(". ")[0][:80]
        recent.append(
            {
                "type": "routing",
                "message": f"[{r.get('route', '?')}] {task}",
                "time": _ago(r.get("timestamp", "")),
            }
        )

    return {
        "total_operations": len(routing),
        "active_operations": active,
        "completed_today": len(ratings),
        "success_rate": success_rate,
        "system_health": system_health,
        "active_pipelines": len(pipelines),
        "recent_activity": recent,
    }


def get_health_status() -> dict:
    """Real component health derived from on-disk state freshness."""
    devloop = _read_json("memory/state/dev-loop-status.json")
    routing = _routing_entries()
    supermem = os.path.isfile(_path("memory/supermemory.json"))

    services = [
        {"name": "Dashboard API", "status": "operational"},
        {
            "name": "Dev Loop",
            "status": "operational" if devloop.get("status") else "unknown",
            "detail": f"phase {devloop.get('phase', '?')}, "
            f"{devloop.get('tests_remaining', '?')} checks remaining",
            "last_run": devloop.get("timestamp", "unknown"),
        },
        {
            "name": "Routing Gate",
            "status": "operational" if routing else "idle",
            "detail": f"{len(routing)} decisions logged",
        },
        {
            "name": "Memory (Supermemory)",
            "status": "configured" if supermem else "unconfigured",
        },
    ]
    degraded = any(s["status"] in {"unknown", "unconfigured"} for s in services)
    return {
        "status": "degraded" if degraded else "operational",
        "services": services,
        "last_check": datetime.now(timezone.utc).isoformat(),
    }


def get_live_status() -> dict:
    """Consolidated real snapshot — phone-readable system state for /api/status/live."""
    devloop = _read_json("memory/state/dev-loop-status.json")
    routing = _routing_entries()
    ratings = _rating_entries()
    return {
        "source": "live",
        "phase": devloop.get("phase"),
        "dev_loop": {
            "status": devloop.get("status"),
            "date": devloop.get("date"),
            "tests_remaining": devloop.get("tests_remaining"),
            "last_run": devloop.get("timestamp"),
        },
        "routing_decisions": len(routing),
        "ratings_count": len(ratings),
        "generated_at": datetime.now(timezone.utc).isoformat(),
    }


def _route_status(r: dict) -> str:
    """Map a routing entry to an operation status using its recorded outcome."""
    if r.get("routing_correct") is False:
        return "failed"
    if isinstance(r.get("outcome_rating"), (int, float)):
        return "completed"
    return "logged"


def get_ai_operations() -> dict:
    """Real 'operations' derived from logged routing decisions + the live dev loop.

    Each routing decision becomes one operation; the current dev-loop run (if active)
    is surfaced as an in-progress operation at the top. Shape matches the old mock:
    a list of {id, name, type, status, created_at} under "operations" with "total".
    """
    routing = _routing_entries()
    operations = []

    devloop = _read_json("memory/state/dev-loop-status.json")
    dl_status = str(devloop.get("status", "")).lower()
    if dl_status:
        running = dl_status in {"progressing", "running", "in_progress", "active"}
        operations.append(
            {
                "id": f"devloop-{devloop.get('date', 'current')}",
                "name": f"Dev loop — phase {devloop.get('phase', '?')}, "
                f"{devloop.get('tests_remaining', '?')} checks remaining",
                "type": "dev_loop",
                "status": "running" if running else dl_status,
                "created_at": devloop.get("timestamp"),
            }
        )

    for i, r in enumerate(
        sorted(routing, key=lambda x: x.get("timestamp", ""), reverse=True)
    ):
        task = (r.get("task") or "Routing decision")[:80]
        operations.append(
            {
                "id": f"route-{i:04d}",
                "name": task,
                "type": str(r.get("route", "route")),
                "status": _route_status(r),
                "created_at": r.get("timestamp"),
            }
        )

    return {"operations": operations, "total": len(operations)}


def _workflow_name(path: str) -> str:
    """Extract a workflow's `name:` field; fall back to the filename."""
    try:
        with open(path, encoding="utf-8") as fh:
            for line in fh:
                stripped = line.strip()
                if stripped.startswith("name:"):
                    name = stripped[len("name:"):].strip().strip("'\"")
                    if name:
                        return name
    except OSError:
        pass
    return os.path.basename(path)


def get_pipelines() -> dict:
    """Real CI/CD pipelines read from .github/workflows/*.yml|*.yaml.

    Status is "configured": runtime querying of the Actions API needs a token we
    deliberately do not embed. Shape matches the old mock: {id, name, status, branch}.
    """
    paths = sorted(
        glob.glob(_path(".github/workflows/*.yml"))
        + glob.glob(_path(".github/workflows/*.yaml"))
    )
    pipelines = []
    for path in paths:
        stem = os.path.splitext(os.path.basename(path))[0]
        pipelines.append(
            {
                "id": f"pipe-{stem}",
                "name": _workflow_name(path),
                "status": "configured",
                "branch": "main",
            }
        )
    return {"pipelines": pipelines, "total": len(pipelines)}


def get_settings() -> dict:
    """Real configuration summary — repo identity + memory service status.

    Reads memory/supermemory.json for the memory bus config. Never surfaces raw
    secret values: the apiKey there is an env-ref placeholder, and we report only
    whether the backing env var is set, never the value itself.
    """
    supermem = _read_json("memory/supermemory.json")
    api_key_ref = str(supermem.get("apiKey", ""))
    # Only report configured-ness, never the raw value. The committed value is an
    # env-ref placeholder ("${SUPERMEMORY_API_KEY}"); resolve presence from the env.
    env_var = str(supermem.get("apiKeySource", "")).split(":", 1)[-1] or "SUPERMEMORY_API_KEY"
    key_configured = bool(os.environ.get(env_var)) or api_key_ref.startswith("${")

    return {
        "identity": {
            "service": "Centaurion",
            "description": "AI-Driven Cognitive Operating System",
            "version": "1.0.0",
        },
        "memory": {
            "service": supermem.get("service", "supermemory"),
            "tier": supermem.get("tier", "unknown"),
            "status": supermem.get("status", "unknown"),
            "api_key_configured": key_configured,
            "auto_capture": bool(supermem.get("autoCapture", False)),
            "auto_recall": bool(supermem.get("autoRecall", False)),
        },
        "preferences": {
            "theme": "dark",
            "auto_refresh": True,
            "refresh_interval": 30,
        },
    }
