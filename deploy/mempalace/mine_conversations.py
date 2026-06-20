#!/usr/bin/env python3
"""MemPalace conversation-export miner (Phase 10 — Knowledge Graph).

Parses a directory of Claude conversation export / transcript files
(.json / .jsonl), extracts candidate "decision" and "fact" statements with
simple, transparent heuristics, and writes a structured
``mempalace-extract.jsonl`` — one JSON object per extracted item:

    {"timestamp": ..., "source_file": ..., "type": ..., "text": ...,
     "speaker": ..., "confidence": ...}

Design constraints (deliberate):
  * STDLIB ONLY. No third-party deps. No network. No API keys.
  * Defensive parsing — never crash on a malformed or unexpected export shape.
  * Friendly + exit 0 on an empty or missing input directory.
  * --help and --dry-run supported.

The extract is the *input* to the downstream emit (Graphiti episodes +
Supermemory documents). That emit is documented in README.md and is NOT
performed here — this script does the offline, key-free extraction pass only.

Hardening notes (validated against real Claude Code transcripts, Phase 10):
  * Real Claude Code transcripts wrap each turn as
    ``{"type": "user|assistant", "message": {"role", "content"}, "timestamp"}``
    — the message is nested under ``message`` and the timestamp lives at the
    TOP level. The parser now unwraps this shape and pulls the top-level
    timestamp down.
  * ``content`` is usually a list of typed blocks
    (``text`` / ``thinking`` / ``tool_use`` / ``tool_result``). Only ``text``
    blocks carry human-readable prose, so tool plumbing is ignored — this
    removes a large class of false positives.
  * Files are read LINE BY LINE (not ``raw.splitlines()``): real transcript
    string values contain embedded newlines, which previously fragmented valid
    JSONL records and produced bogus "malformed line" warnings.
  * A small set of NEGATIVE-CONTEXT phrases suppresses narration / meta /
    instruction matches ("let me bring you decisions", "that's your decision").
  * Each extraction carries a transparent ``confidence`` score, and exact
    duplicate statements are de-duplicated.
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
#
# STRONG decision phrases — verb-led, high precision. These score higher.
DECISION_STRONG = [
    "we decided",
    "i decided",
    "we've decided",
    "i've decided",
    "decided to",
    "we chose",
    "i chose",
    "we picked",
    "we'll use",
    "we will use",
    "we're going with",
    "we are going with",
    "let's go with",
    "going with",
    "we settled on",
    "settled on",
    "we opted for",
    "opted for",
    "we switched to",
    "switched to",
    "we'll migrate",
    "we are migrating",
    "we're migrating",
    "decision is to",
    "decision: ",
    "we should use",
    "let's use",
]

# WEAK decision signals — lower precision (bare nouns / generic verbs). They
# still count, but at lower confidence so reviewers can threshold them out.
DECISION_WEAK = [
    "decision",
    "decided",
    "chose",
    "choosing",
    "picked",
    "go with",
    "switch to",
    "migrate from",
    "migrating",
    "migrated",
    "will use",
]

FACT_STRONG = [
    "the reason is",
    "the reason we",
    "turns out",
    "key insight",
    "the key is",
]

FACT_WEAK = [
    "because",
    "the reason",
    "note that",
    "note:",        # NB: doc callouts ("> **Note:**") match here at LOW conf
    "important:",
    "important",
    "key insight",
]

# Negative-context phrases: if a sentence contains one of these, it is almost
# always narration / meta / instruction rather than a recorded decision or
# fact. Suppress the match entirely. Derived from real-transcript false
# positives ("let me ... bring you decisions", "that's the user's decision",
# "before choosing the ... tier", documentation cross-references, etc.).
NEGATIVE_CONTEXT = [
    "let me",
    "i'll bring",
    "bring you decision",
    "your decision",
    "user's decision",
    "the user's decision",
    "not yours",
    "before choosing",
    "before you choose",
    "see `",        # documentation cross-reference
    "see shared/",
    "→ migrating",  # doc heading cross-reference
    "decision tree",
    "never downgrade",
    "never choose",
    "never mix",
    "for details",
]

# Split a message body into sentence-ish units so we capture the specific
# statement rather than a whole paragraph.
_SENTENCE_SPLIT = re.compile(r"(?<=[.!?])\s+|\n+")

# Cap how much text we keep per extracted item (defensive against giant blobs).
MAX_TEXT_LEN = 600

# Only mine human-readable conversational roles. Injected system/tool content
# is noisier; keep the corpus to what people and the assistant actually said.
MINEABLE_ROLES = {"user", "assistant", "human"}


def _has_any(low: str, phrases: Iterable[str]) -> bool:
    return any(p in low for p in phrases)


def classify(line: str) -> tuple[str, float] | None:
    """Return (kind, confidence) for a single sentence/line, or None.

    Confidence is a transparent 0..1 heuristic score, NOT a probability:
      * strong decision phrase -> 0.8 base
      * weak decision signal   -> 0.45 base
      * strong fact marker     -> 0.7 base
      * weak fact marker       -> 0.4 base
    A negative-context phrase suppresses the match (returns None).
    Very short fragments are penalised; question sentences are penalised
    (questions are rarely a recorded decision/fact).
    """
    low = line.lower()

    if _has_any(low, NEGATIVE_CONTEXT):
        return None

    kind: str | None = None
    base = 0.0
    if _has_any(low, DECISION_STRONG):
        kind, base = "decision", 0.8
    elif _has_any(low, DECISION_WEAK):
        kind, base = "decision", 0.45
    elif _has_any(low, FACT_STRONG):
        kind, base = "fact", 0.7
    elif _has_any(low, FACT_WEAK):
        kind, base = "fact", 0.4

    if kind is None:
        return None

    conf = base
    # Penalise questions — "should we migrate?" is deliberation, not a decision.
    if line.rstrip().endswith("?"):
        conf -= 0.2
    # Penalise tiny fragments (little context to be a real statement).
    n_words = len(line.split())
    if n_words < 4:
        conf -= 0.15
    elif n_words >= 8:
        conf += 0.05
    # Bonus: a concrete proper-noun-ish token often means a real subject.
    if re.search(r"\b[A-Z][a-zA-Z]{3,}\b", line):
        conf += 0.05

    conf = round(max(0.0, min(1.0, conf)), 2)
    return kind, conf


def _coerce_text(content: Any) -> str:
    """Coerce a Claude message body to human-readable text.

    Handles: plain string; list of content blocks; dict with text/value.
    For block lists we keep ONLY ``text`` blocks (and untyped blocks that still
    carry a ``text`` field). ``thinking`` / ``tool_use`` / ``tool_result``
    blocks are skipped — they are plumbing, not prose, and were a major source
    of false positives on real transcripts.
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
                btype = block.get("type")
                if btype in ("thinking", "tool_use", "tool_result"):
                    continue  # skip plumbing
                txt = block.get("text") or block.get("value")
                if txt:
                    parts.append(str(txt))
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
      * Claude Code transcript line:
          {"type": "user|assistant", "message": {"role","content"},
           "timestamp": ...}
        -> the nested ``message`` is unwrapped and the TOP-LEVEL timestamp is
           carried down (real transcripts put the timestamp at the top, not in
           the message).
      * {"messages": [ ... ]}                     (conversation object)
      * {"chat_messages": [ ... ]}                (claude.ai export variant)
      * [ {conversation}, {conversation}, ... ]   (list of conversations)
      * [ {message}, {message}, ... ]             (flat list of messages)
      * {message}                                 (single message)
    """
    if isinstance(obj, dict):
        # Claude Code transcript: nested message + top-level timestamp.
        nested = obj.get("message")
        if isinstance(nested, dict) and (
            "role" in nested or "content" in nested
        ):
            top_ts = _timestamp_of(obj, None)
            if top_ts and not _timestamp_of(nested, None):
                nested = {**nested, "_conv_ts": top_ts}
            yield nested
            return

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
    """Yield top-level parsed objects from a .json or .jsonl file, defensively.

    Strategy:
      1. Try whole-file JSON (covers .json and single-object files).
      2. Otherwise treat as JSONL and parse LINE BY LINE from the file handle.
         Reading real lines (not ``raw.splitlines()``) is important: transcript
         string values contain embedded newlines that ``splitlines`` would
         wrongly treat as record boundaries.
    """
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

    # Fall back to line-delimited JSON (.jsonl). Iterate REAL lines so embedded
    # newlines inside JSON string values don't fragment valid records.
    ok = False
    malformed = 0
    try:
        with open(path, "r", encoding="utf-8", errors="replace") as fh:
            for _lineno, line in enumerate(fh, 1):
                line = line.strip()
                if not line:
                    continue
                try:
                    yield json.loads(line)
                    ok = True
                except json.JSONDecodeError:
                    malformed += 1
    except OSError as exc:
        print(f"  ! skip {os.path.basename(path)}: cannot read ({exc})", file=sys.stderr)
        return

    if malformed:
        print(
            f"  ! {os.path.basename(path)}: skipped {malformed} malformed line(s)",
            file=sys.stderr,
        )
    if not ok:
        print(f"  ! {os.path.basename(path)}: no parseable JSON found", file=sys.stderr)


def extract_from_file(path: str) -> Iterator[dict]:
    """Yield extract records from a single export file."""
    source = os.path.basename(path)
    for obj in _load_file(path):
        for msg in _iter_messages(obj):
            speaker = _speaker_of(msg)
            # Only mine human-readable conversational roles.
            if speaker.lower() not in MINEABLE_ROLES:
                continue
            text = _coerce_text(msg.get("content") if "content" in msg else msg.get("text"))
            if not text:
                continue
            ts = _timestamp_of(msg, msg.get("_conv_ts"))
            for sentence in _SENTENCE_SPLIT.split(text):
                sentence = sentence.strip()
                if not sentence:
                    continue
                result = classify(sentence)
                if result is None:
                    continue
                kind, confidence = result
                yield {
                    "timestamp": ts,
                    "source_file": source,
                    "type": kind,
                    "text": sentence[:MAX_TEXT_LEN],
                    "speaker": speaker,
                    "confidence": confidence,
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
            "Mine Claude conversation exports / transcripts (.json/.jsonl) into "
            "a structured mempalace-extract.jsonl of decision/fact statements. "
            "Stdlib-only, no network, no API keys. Safe on an empty/missing dir."
        ),
        epilog="Downstream emit to Graphiti/Supermemory is documented in README.md.",
    )
    parser.add_argument(
        "input_dir",
        nargs="?",
        default="exports",
        help="directory of Claude export/transcript files (default: ./exports)",
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
    parser.add_argument(
        "--min-confidence",
        type=float,
        default=0.0,
        help="drop extractions below this confidence (0..1, default: 0.0)",
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
    seen: set[tuple[str, str]] = set()  # (type, normalized-text) -> dedup
    n_dupes = 0
    n_below_conf = 0
    for path in files:
        n_before = len(records)
        for rec in extract_from_file(path):
            if rec["confidence"] < args.min_confidence:
                n_below_conf += 1
                continue
            key = (rec["type"], " ".join(rec["text"].lower().split()))
            if key in seen:
                n_dupes += 1
                continue
            seen.add(key)
            records.append(rec)
        print(f"  - {os.path.basename(path)}: {len(records) - n_before} item(s)")

    n_decisions = sum(1 for r in records if r["type"] == "decision")
    n_facts = sum(1 for r in records if r["type"] == "fact")
    extras = []
    if n_dupes:
        extras.append(f"{n_dupes} duplicate(s) collapsed")
    if n_below_conf:
        extras.append(f"{n_below_conf} below min-confidence dropped")
    suffix = f"  ({'; '.join(extras)})" if extras else ""
    print(
        f"Extracted {len(records)} unique item(s): "
        f"{n_decisions} decision, {n_facts} fact.{suffix}"
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
