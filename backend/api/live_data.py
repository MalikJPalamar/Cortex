"""Live data provider — reads REAL Centaurion state instead of mock fixtures.

The committed state files (routing-log, ratings, dev-loop status, STATE.md) and the
GitHub workflow definitions ship inside the Render image, so the deployed dashboard
can surface genuine system state. Every reader is defensive: if a file is missing or
malformed, it degrades to safe zeros/empties rather than raising — the dashboard must
never 500 because a log rotated.
"""
import glob
import json
import os
from datetime import datetime, timezone

# backend/api/live_data.py -> repo root is two levels up. Overridable for tests.
_HERE = os.path.dirname(os.path.abspath(__file__))
REPO_ROOT = os.environ.get(
    "CENTAURION_REPO", os.path.abspath(os.path.join(_HERE, "..", ".."))
)


def _path(rel: str) -> str:
    return os.path.join(REPO_ROOT, rel)


def _read_jsonl(rel: str) -> list:
    """Read a .jsonl file into a list of dicts, skipping blanks/bad lines."""
    rows = []
    p = _path(rel)
    if os.path.isfile(p):
        with open(p, encoding="utf-8") as fh:
            for line in fh:
                line = line.strip()
                if not line:
                    continue
                try:
                    rows.append(json.loads(line))
                except json.JSONDecodeError:
                    continue
    return rows


def _read_json(rel: str) -> dict:
    p = _path(rel)
    if os.path.isfile(p):
        try:
            with open(p, encoding="utf-8") as fh:
                return json.load(fh)
        except (json.JSONDecodeError, OSError):
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
