#!/usr/bin/env python3
"""MemPalace conversation-export miner (Phase 10 — Knowledge Graph).

Parses a directory of Claude conversation export files (.json / .jsonl),
extracts candidate "decision" and "fact" statements with simple, transparent
heuristics, and writes a structured ``mempalace-extract.jsonl`` — one JSON
object per extracted item:

    {"timestamp": ..., "source_file": ..., "type": ..., "text": ..., "speaker": ...}

Design constraints (deliberate):
  * STDLIB ONLY. No third-party deps. No network. No API keys.
  * Defensive parsing — never crash on a malformed or unexpected export shape.
  * Friendly + exit 0 on an empty or missing input directory.
  * --help and --dry-run supported.

The extract is the *input* to the downstream emit (Graphiti episodes +
Supermemory documents). That emit is documented in README.md and is NOT
performed here — this script does the offline, key-free extraction pass only.
"""

from __future__ import annotations

import argparse
import json
import os
import re
import sys
from typing import Any, Iterable, Iterator

# --- Heuristics --------------------------------------------------------------
# Lowercased substrings. Kept small and legible on purpose: this is a
# recall-first first pass, not an NLP model. Tune the lists freely.

DECISION_VERBS = [
    "decided",
    "decision",
    "chose",
    "choosing",
    "will use",
    "we'll use",
    "going with",
    "go with",
    "let's go with",
    "switched to",
    "switch to",
    "migrated",
    "migrate from",
    "migrating",
    "settled on",
    "picked",
    "opted for",
    "we should use",
]

FACT_MARKERS = [
    "because",
    "the reason",
    "turns out",
    "note that",
    "important:",
    "key insight",
    "the key is",
]

# Split a message body into sentence-ish units so we capture the specific
# statement rather than a whole paragraph.
_SENTENCE_SPLIT = re.compile(r"(?<=[.!?])\s+|\n+")

# Cap how much text we keep per extracted item (defensive against giant blobs).
MAX_TEXT_LEN = 600


def classify(line: str) -> str | None:
    """Return 'decision', 'fact', or None for a single sentence/line."""
    low = line.lower()
    for verb in DECISION_VERBS:
        if verb in low:
            return "decision"
    for marker in FACT_MARKERS:
        if marker in low:
            return "fact"
    return None


def _coerce_text(content: Any) -> str:
    """Claude exports put message bodies in several shapes. Coerce to text.

    Handles: plain string; list of content blocks ({"type":"text","text":...}
    or {"text":...}); dict with a 'text'/'value' field; anything else -> "".
    """
    if content is None:
        return ""
    if isinstance(content, str):
        return content
    if isinstance(content, list):
        parts = []
        for block in content:
            if isinstance(block, str):
                parts.append(block)
            elif isinstance(block, dict):
                parts.append(str(block.get("text") or block.get("value") or ""))
        return "\n".join(p for p in parts if p)
    if isinstance(content, dict):
        return str(content.get("text") or content.get("value") or "")
    return ""


def _speaker_of(msg: dict) -> str:
    for key in ("role", "sender", "author", "speaker", "from"):
        val = msg.get(key)
        if isinstance(val, str) and val:
            return val
        if isinstance(val, dict):
            name = val.get("role") or val.get("name")
            if name:
                return str(name)
    return "unknown"


def _timestamp_of(msg: dict, fallback: str | None) -> str | None:
    for key in ("created_at", "timestamp", "time", "createdAt", "updated_at", "date"):
        val = msg.get(key)
        if val:
            return str(val)
    return fallback


def _iter_messages(obj: Any) -> Iterator[dict]:
    """Yield message-like dicts from an arbitrary export object, defensively.

    Recognized shapes:
      * {"messages": [ ... ]}                     (conversation object)
      * {"chat_messages": [ ... ]}                (claude.ai export variant)
      * [ {conversation}, {conversation}, ... ]   (list of conversations)
      * [ {message}, {message}, ... ]             (flat list of messages)
      * {message}                                 (single message)
    """
    if isinstance(obj, dict):
        for key in ("messages", "chat_messages", "conversation", "turns"):
            if isinstance(obj.get(key), list):
                # carry conversation-level timestamp down as a fallback
                conv_ts = _timestamp_of(obj, None)
                for m in obj[key]:
                    if isinstance(m, dict):
                        if conv_ts and not _timestamp_of(m, None):
                            m = {**m, "_conv_ts": conv_ts}
                        yield m
                return
        # looks like a bare message itself?
        if any(k in obj for k in ("role", "content", "text", "sender", "author")):
            yield obj
        return
    if isinstance(obj, list):
        for item in obj:
            yield from _iter_messages(item)


def _load_file(path: str) -> Iterator[Any]:
    """Yield top-level parsed objects from a .json or .jsonl file, defensively."""
    try:
        with open(path, "r", encoding="utf-8", errors="replace") as fh:
            raw = fh.read()
    except OSError as exc:
        print(f"  ! skip {os.path.basename(path)}: cannot read ({exc})", file=sys.stderr)
        return

    stripped = raw.strip()
    if not stripped:
        return

    # Try whole-file JSON first (covers .json and single-object .jsonl).
    try:
        yield json.loads(stripped)
        return
    except json.JSONDecodeError:
        pass

    # Fall back to line-delimited JSON (.jsonl).
    ok = False
    for lineno, line in enumerate(stripped.splitlines(), 1):
        line = line.strip()
        if not line:
            continue
        try:
            yield json.loads(line)
            ok = True
        except json.JSONDecodeError:
            print(
                f"  ! skip malformed line {lineno} in {os.path.basename(path)}",
                file=sys.stderr,
            )
    if not ok:
        print(f"  ! {os.path.basename(path)}: no parseable JSON found", file=sys.stderr)


def extract_from_file(path: str) -> Iterator[dict]:
    """Yield extract records from a single export file."""
    source = os.path.basename(path)
    for obj in _load_file(path):
        for msg in _iter_messages(obj):
            text = _coerce_text(msg.get("content") if "content" in msg else msg.get("text"))
            if not text:
                continue
            speaker = _speaker_of(msg)
            ts = _timestamp_of(msg, msg.get("_conv_ts"))
            for sentence in _SENTENCE_SPLIT.split(text):
                sentence = sentence.strip()
                if not sentence:
                    continue
                kind = classify(sentence)
                if kind is None:
                    continue
                yield {
                    "timestamp": ts,
                    "source_file": source,
                    "type": kind,
                    "text": sentence[:MAX_TEXT_LEN],
                    "speaker": speaker,
                }


def find_exports(directory: str) -> list[str]:
    out = []
    for root, _dirs, files in os.walk(directory):
        for name in sorted(files):
            if name.lower().endswith((".json", ".jsonl")):
                out.append(os.path.join(root, name))
    return sorted(out)


def main(argv: Iterable[str] | None = None) -> int:
    parser = argparse.ArgumentParser(
        prog="mine_conversations.py",
        description=(
            "Mine Claude conversation exports (.json/.jsonl) into a structured "
            "mempalace-extract.jsonl of decision/fact statements. Stdlib-only, "
            "no network, no API keys. Safe to run on an empty/missing dir."
        ),
        epilog="Downstream emit to Graphiti/Supermemory is documented in README.md.",
    )
    parser.add_argument(
        "input_dir",
        nargs="?",
        default="exports",
        help="directory of Claude export files (default: ./exports)",
    )
    parser.add_argument(
        "--out",
        default="mempalace-extract.jsonl",
        help="output JSONL path (default: ./mempalace-extract.jsonl)",
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="parse and report counts but write no output file",
    )
    args = parser.parse_args(list(argv) if argv is not None else None)

    in_dir = args.input_dir

    if not os.path.isdir(in_dir):
        print(
            f"MemPalace miner: input directory '{in_dir}' not found.\n"
            f"  Nothing to mine. Put Claude exports (.json/.jsonl) there and re-run.\n"
            f"  See deploy/mempalace/README.md for how to obtain exports."
        )
        return 0

    files = find_exports(in_dir)
    if not files:
        print(
            f"MemPalace miner: no .json/.jsonl exports under '{in_dir}'.\n"
            f"  Nothing to mine. (Friendly exit.)"
        )
        return 0

    print(f"MemPalace miner: scanning {len(files)} export file(s) under '{in_dir}'...")

    records: list[dict] = []
    for path in files:
        n_before = len(records)
        for rec in extract_from_file(path):
            records.append(rec)
        print(f"  - {os.path.basename(path)}: {len(records) - n_before} item(s)")

    n_decisions = sum(1 for r in records if r["type"] == "decision")
    n_facts = sum(1 for r in records if r["type"] == "fact")
    print(
        f"Extracted {len(records)} item(s): "
        f"{n_decisions} decision, {n_facts} fact."
    )

    if args.dry_run:
        print("--dry-run: no output written.")
        # Show a small preview so the operator can sanity-check heuristics.
        for rec in records[:5]:
            print("    " + json.dumps(rec, ensure_ascii=False))
        if len(records) > 5:
            print(f"    ... (+{len(records) - 5} more)")
        return 0

    with open(args.out, "w", encoding="utf-8") as fh:
        for rec in records:
            fh.write(json.dumps(rec, ensure_ascii=False) + "\n")
    print(f"Wrote {len(records)} record(s) -> {args.out}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
