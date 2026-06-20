# MemPalace — Claude Conversation-Export Miner (Phase 10 / Knowledge Graph)

> **Status: SCAFFOLD — runnable today.** The extraction pass is real, stdlib-only,
> and needs no API key or network. The downstream emit to Graphiti + Supermemory
> is documented below but **intentionally not fabricated** — no live round-trip is
> claimed.

MemPalace is **Layer 3** of the memory stack: the *verbatim archive*. This piece
is its front-end miner — it reads Claude conversation exports and turns
decision/fact statements into a structured extract that feeds the knowledge
graph. It is the concrete answer to the Phase 10 Definition of Done:

> *"Agent answers 'When did we decide to migrate from Ontraport?' from Graphiti."*

Every extracted **decision** carries a `timestamp` + `speaker` + verbatim `text`,
so "when did we decide X?" becomes a lookup once these land as Graphiti episodes.

---

## 1. Where Claude exports live / how to obtain them

The miner accepts any directory of `.json` / `.jsonl` files in a Claude-ish shape.
Two common sources:

| Source | How to get it |
|--------|---------------|
| **claude.ai data export** | claude.ai → Settings → *Account* → **Export data**. You receive a zip containing `conversations.json` (an array of conversation objects, each with a `chat_messages` / `messages` list). Unzip it into `deploy/mempalace/exports/`. |
| **Claude Code session transcripts** | Local JSONL transcripts under `~/.claude/projects/<project>/*.jsonl`. Copy or symlink the ones you want mined into `deploy/mempalace/exports/`. |

The parser is **defensive**: it handles conversation objects (`{"messages": [...]}`
or `{"chat_messages": [...]}`), bare lists of conversations, flat lists of
messages, single messages, and several content shapes (string, list of content
blocks, `{text|value}` dicts). Malformed lines/files are skipped with a warning,
not a crash.

> **Privacy:** `deploy/mempalace/exports/` is **gitignored**. Raw transcripts hold
> private content — never commit them. Only the `.gitkeep` placeholder is tracked.

---

## 2. Run the miner

No install step. Python 3 stdlib only.

```bash
cd deploy/mempalace

# See all options
python3 mine_conversations.py --help

# Dry run: parse + count + preview, write nothing
python3 mine_conversations.py exports --dry-run

# Real run: writes mempalace-extract.jsonl next to you
python3 mine_conversations.py exports

# Custom output path
python3 mine_conversations.py /path/to/exports --out /tmp/extract.jsonl
```

Safe edge cases (both exit `0` with a friendly message, no traceback):

```bash
python3 mine_conversations.py ./does-not-exist   # missing dir
python3 mine_conversations.py exports            # empty dir
```

---

## 3. What it extracts

For every message it splits the body into sentence-ish units and classifies each:

- **`decision`** — contains a decision phrase, split into **strong** (verb-led:
  `we decided`, `decided to`, `going with`, `switched to`, `we'll use`,
  `opted for`, `settled on`, …) and **weak** (bare nouns / generic verbs:
  `decision`, `chose`, `migrating`, `will use`, …). Full lists in
  `mine_conversations.py`.
- **`fact`** — contains a fact marker: `the reason is`, `turns out`,
  `key insight`, `because`, `note that`, …

Each match is suppressed if the sentence also hits a **negative-context** phrase
(narration / meta / instruction / doc cross-reference, e.g. `let me`,
`that's your decision`, `before choosing`, `see \``). This is the main
false-positive killer surfaced by real-data validation (see §6).

Output: **`mempalace-extract.jsonl`**, one JSON object per item:

```json
{"timestamp": "2026-03-02T14:11:00Z", "source_file": "synthetic_transcript.jsonl", "type": "decision", "text": "We decided to migrate from Ontraport to GoHighLevel for the BuilderBee CRM.", "speaker": "assistant", "confidence": 0.9}
```

| Field | Meaning |
|-------|---------|
| `timestamp` | message time (Claude Code transcripts: pulled from the **top-level** turn timestamp; falls back to conversation-level time, or `null`) |
| `source_file` | export filename the item came from |
| `type` | `decision` or `fact` |
| `text` | the verbatim statement (capped at 600 chars) |
| `speaker` | `role` / `sender` / `author` (e.g. `human`, `assistant`) |
| `confidence` | transparent `0..1` heuristic score (strong phrase ≈ 0.8, weak ≈ 0.45; questions and tiny fragments are penalised). Use `--min-confidence 0.8` for a high-precision decision shortlist. |

This is a **recall-first** heuristic pass — it favors catching real decisions
over precision, then exposes `confidence` + `--min-confidence` so the noisy tail
can be thresholded out. Exact-duplicate statements are de-duplicated. Tune the
phrase lists in the script as the corpus grows.

---

## 3a. Reproduce without real data (synthetic fixture)

`sample/` holds a **synthetic** (fake-but-realistic) Claude Code transcript that
contains the canonical Ontraport→GoHighLevel migration decision — **no real
conversation content**. Run the demo to reproduce the extract end-to-end:

```bash
deploy/mempalace/sample/run_demo.sh
```

Expected extract (the Phase-10 DoD decision lands at confidence `0.9` with its
timestamp):

```json
{"timestamp": "2026-03-02T14:09:10Z", "source_file": "synthetic_transcript.jsonl", "type": "decision", "text": "Okay, let's go with GoHighLevel then.", "speaker": "user", "confidence": 0.85}
{"timestamp": "2026-03-02T14:11:00Z", "source_file": "synthetic_transcript.jsonl", "type": "decision", "text": "We decided to migrate from Ontraport to GoHighLevel for the BuilderBee CRM.", "speaker": "assistant", "confidence": 0.9}
```

The fixture also includes a `thinking` block, a `tool_use`/`tool_result` pair,
and a "let me bring you the rollout decisions" narration line — all of which the
miner correctly **ignores** (plumbing skipped; narration suppressed by
negative-context).

---

## 6. Real-transcript validation (Phase 10 hardening — stats only, no content)

The miner was validated against this host's real Claude Code transcripts under
`~/.claude/projects/**/*.jsonl` (**48 files, ~7,900 lines**). Only counts and
findings are reported here — **no conversation content was committed**.

**Before hardening:** `0` items extracted. The prior parser did not recognise
the real Claude Code transcript shape (it expected `messages` /
`chat_messages`), and `raw.splitlines()` fragmented long JSONL records on
newlines embedded inside string values, emitting bogus "malformed line"
warnings.

**After hardening:**

| Metric | Value |
|--------|-------|
| Files scanned | 48 |
| Unique items extracted | **306** |
| — decisions | 182 |
| — facts | 124 |
| Duplicates collapsed (dedup) | 101 |
| Malformed-line warnings | 0 (was 16 false ones) |
| High-confidence tier (`--min-confidence 0.8`) | 11 items → 8 decision / 3 fact |

**Precision (qualitative):** the **`>=0.8`** tier is decision-dominant and
verb-led — these read as genuine recorded decisions. The bulk of items sit in
the **`0.45–0.59`** weak tier, which mixes real decisions with narration and
pasted skill/CLAUDE.md doc text injected under `role: user`. Real-data findings
that drove the hardening:

- Bare noun `decision(s)` fired on narration ("let me bring you decisions",
  "that's the user's decision") → added **negative-context suppression** +
  demoted bare nouns to **weak** confidence.
- Markdown doc callouts (`> **Note:**`, `Important:`) from pasted API docs
  flooded the strong-fact tier → demoted `note:` / `important:` to **weak**.
- `tool_use` / `tool_result` / `thinking` blocks produced noise → the parser now
  mines **only `text` blocks** from `user` / `assistant` roles.

Net: precision at the high-confidence tier went from ~12% real-decisions
(pre-fix, dominated by doc `Note:` callouts) to a clean decision-dominant
shortlist. Recall is preserved in the weak tier for later re-ranking.

---

## 4. Where the output goes (downstream — documented, not wired)

`mempalace-extract.jsonl` is the hand-off into the knowledge graph. Two sinks:

### a. Graphiti (primary) — `memory/graphiti.json`

Each record becomes a **temporal episode**. With Graphiti's MCP/SDK wired to the
live Neo4j on VPS1 (`bolt://…:7687`), the loop is:

```text
for record in mempalace-extract.jsonl:
    graphiti.add_episode(
        name=f"{record['type']}:{record['source_file']}",
        episode_body=record['text'],
        reference_time=record['timestamp'],   # makes "when did we decide X?" answerable
        source_description=f"mempalace miner / speaker={record['speaker']}",
    )
```

This is the step that satisfies the Phase 10 DoD: decisions land as
timestamped episodes, so Graphiti can answer *"When did we first decide to
migrate from Ontraport?"*.

### b. Supermemory (secondary) — `memory/supermemory.json`

Each record is also written as a **document** to the relevant container
(`aob` / `builderbee` / `centaurion`) via `POST /v3/documents`, giving the
real-time bus a searchable copy.

> **Why not wired here:** wiring requires a live Neo4j password
> (`NEO4J_PASSWORD`) and `SUPERMEMORY_API_KEY`, both of which live only in the
> host `/root/Centaurion/.env` (gitignored, `600`). Per the project's
> no-fabrication rule, the emit is left as a documented, copy-pasteable step
> rather than a fake "verified" integration. Set those env vars on the host to
> light it up.

---

## 5. How this supports Phase 10

```text
Claude exports ──▶ mine_conversations.py ──▶ mempalace-extract.jsonl
                     (decisions + facts,            │
                      timestamped, verbatim)        ▼
                                          Graphiti episodes (temporal)  ──▶ "When did we decide X?"
                                          Supermemory documents (recall)
```

The miner is the deterministic, offline bridge between raw conversation history
and the temporal graph. It needs no keys to produce value today; the graph emit
flips on the moment the sibling Graphiti scaffold is wired.

---

## Files

| File | Purpose |
|------|---------|
| `memory/mempalace.json` | Integration descriptor (status, miner spec, downstream sinks, env refs) |
| `deploy/mempalace/mine_conversations.py` | The miner (stdlib-only, `--help`, `--dry-run`, `--min-confidence`) |
| `deploy/mempalace/README.md` | This runbook |
| `deploy/mempalace/exports/` | Drop Claude exports here (**gitignored** — only `.gitkeep` tracked) |
| `deploy/mempalace/sample/` | **Synthetic** fixture + `run_demo.sh` — reproduce the extract with no real data |

## Operator step (the one thing left to go live downstream)

Wire the sibling **Graphiti** scaffold (`memory/graphiti.json`) — set
`NEO4J_PASSWORD` (and optionally `SUPERMEMORY_API_KEY`) in
`/root/Centaurion/.env` — then run the emit loop in §4 over the extract. The
extraction pass itself already runs with zero setup.
