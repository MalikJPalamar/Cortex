"""Smoke tests for the Centaurion exo-cortex.

These validate the core structural invariants of the framework using only the
Python standard library, so they run in CI without any extra dependencies.

Before this suite existed, `pytest` collected 0 items and exited with code 5,
which GitHub Actions treats as a failure — turning every CI run red.
"""

import json
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent


def test_repo_root_resolved():
    """The test file can locate the repository root."""
    assert (REPO_ROOT / "CLAUDE.md").is_file()


def test_three_laws_present():
    """CLAUDE.md must declare the Three Laws that govern the agent."""
    text = (REPO_ROOT / "CLAUDE.md").read_text(encoding="utf-8")
    for law in ("Hierarchy Law", "Routing Law", "Coupling Law"):
        assert law in text, f"Missing '{law}' in CLAUDE.md"


def test_core_directories_exist():
    """The exo-cortex layout must be intact."""
    for name in ("identity", "framework", "agents", "skills", "memory", "workflows"):
        assert (REPO_ROOT / name).is_dir(), f"Missing core directory: {name}/"


def test_identity_files_present():
    """The TELOS identity system requires these calibration files."""
    identity = REPO_ROOT / "identity"
    for name in ("PURPOSE.md", "MISSION.md", "GOALS.md", "PREFERENCES.md"):
        assert (identity / name).is_file(), f"Missing identity file: {name}"


def test_jsonl_memory_files_parse():
    """Append-only memory logs must contain valid JSON on every line."""
    state = REPO_ROOT / "memory" / "state"
    for fname in ("routing-log.jsonl", "ratings.jsonl"):
        path = state / fname
        if not path.exists():
            continue
        for i, line in enumerate(path.read_text(encoding="utf-8").splitlines(), 1):
            line = line.strip()
            if not line:
                continue
            json.loads(line)  # raises if malformed -> test fails


def test_json_state_files_parse():
    """Every *.json state file must be parseable."""
    state = REPO_ROOT / "memory" / "state"
    for path in state.glob("*.json"):
        json.loads(path.read_text(encoding="utf-8"))
