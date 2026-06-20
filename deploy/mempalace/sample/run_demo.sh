#!/usr/bin/env bash
# MemPalace miner demo — runs the miner against the SYNTHETIC fixture only.
#
# This contains NO real conversation content. It lets a reviewer reproduce the
# extraction (and the Ontraport-migration decision capture) without any private
# data or API keys. Stdlib Python 3 only.
#
# Usage:
#   deploy/mempalace/sample/run_demo.sh
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MINER="$HERE/../mine_conversations.py"
FIXTURE_DIR="$HERE"   # the synthetic .jsonl lives here

echo "=== MemPalace miner demo (synthetic fixture) ==="
echo "miner:   $MINER"
echo "fixture: $FIXTURE_DIR/synthetic_transcript.jsonl"
echo

echo "--- 1. --help ---"
python3 "$MINER" --help
echo

echo "--- 2. dry-run over the synthetic fixture ---"
python3 "$MINER" "$FIXTURE_DIR" --dry-run

echo
echo "--- 3. write extract to a temp file and show it ---"
OUT="$(mktemp -t mempalace-demo-XXXX.jsonl)"
python3 "$MINER" "$FIXTURE_DIR" --out "$OUT"
echo
echo "Extract contents ($OUT):"
cat "$OUT"
rm -f "$OUT"

echo
echo "--- 4. empty-dir behaviour (graceful exit 0) ---"
EMPTY="$(mktemp -d)"
python3 "$MINER" "$EMPTY"
rmdir "$EMPTY"

echo
echo "=== demo complete ==="
