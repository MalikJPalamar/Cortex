#!/usr/bin/env bash
# Centaurion v0.1 — Core Loop Verification Script
# Tests all requirements R1-R10 from .planning/REQUIREMENTS.md
# Usage: bash tests/verify-core-loop.sh
# Exit 0 = all pass, Exit 1 = failures found

set -euo pipefail

# --- Setup ---
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PASS=0
FAIL=0
TOTAL=0

pass() {
  PASS=$((PASS + 1))
  TOTAL=$((TOTAL + 1))
  echo "  ✓ $1"
}

fail() {
  FAIL=$((FAIL + 1))
  TOTAL=$((TOTAL + 1))
  echo "  ✗ $1"
}

check_file_exists() {
  if [ -f "$REPO_ROOT/$1" ]; then
    pass "$2"
  else
    fail "$2 — file not found: $1"
  fi
}

check_file_nonempty() {
  if [ -f "$REPO_ROOT/$1" ] && [ -s "$REPO_ROOT/$1" ]; then
    pass "$2"
  else
    fail "$2 — file missing or empty: $1"
  fi
}

check_file_contains() {
  local file="$1" pattern="$2" desc="$3"
  if [ -f "$REPO_ROOT/$file" ] && grep -qi "$pattern" "$REPO_ROOT/$file"; then
    pass "$desc"
  else
    fail "$desc — pattern '$pattern' not found in $file"
  fi
}

check_file_contains_exact() {
  local file="$1" pattern="$2" desc="$3"
  if [ -f "$REPO_ROOT/$file" ] && grep -q "$pattern" "$REPO_ROOT/$file"; then
    pass "$desc"
  else
    fail "$desc — pattern '$pattern' not found in $file"
  fi
}

# ============================================================
# R1: Identity Loading (L0 Sensing)
# ============================================================
echo ""
echo "═══ R1: Identity Loading (L0 Sensing) ═══"

# R1.1: CLAUDE.md exists at repo root
check_file_exists "CLAUDE.md" "R1.1: CLAUDE.md exists at repo root"

# R1.2: CLAUDE.md references Cortex as agent identity
check_file_contains "CLAUDE.md" "Cortex" "R1.2: CLAUDE.md references Cortex"

# R1.3: CLAUDE.md references core identity files
check_file_contains "CLAUDE.md" "PURPOSE.md" "R1.3a: CLAUDE.md references PURPOSE.md"
check_file_contains "CLAUDE.md" "MISSION.md" "R1.3b: CLAUDE.md references MISSION.md"
check_file_contains "CLAUDE.md" "GOALS.md" "R1.3c: CLAUDE.md references GOALS.md"
check_file_contains "CLAUDE.md" "PREFERENCES.md" "R1.3d: CLAUDE.md references PREFERENCES.md"

# R1.4: All 10 identity files exist and are non-empty
IDENTITY_FILES="PURPOSE.md MISSION.md GOALS.md CHALLENGES.md CONTACTS.md BELIEFS.md MODELS.md PREFERENCES.md HISTORY.md OPINIONS.md"
for f in $IDENTITY_FILES; do
  check_file_nonempty "identity/$f" "R1.4: identity/$f exists and non-empty"
done

# R1.5: PURPOSE.md contains Precision Ratio
check_file_contains "identity/PURPOSE.md" "Predictive Order" "R1.5a: PURPOSE.md contains Predictive Order"
check_file_contains "identity/PURPOSE.md" "Thermodynamic Cost" "R1.5b: PURPOSE.md contains Thermodynamic Cost"

# R1.6: MISSION.md contains Three Laws
check_file_contains "identity/MISSION.md" "Hierarchy Law" "R1.6a: MISSION.md contains Hierarchy Law"
check_file_contains "identity/MISSION.md" "Routing Law" "R1.6b: MISSION.md contains Routing Law"
check_file_contains "identity/MISSION.md" "Coupling Law" "R1.6c: MISSION.md contains Coupling Law"

# R1.7: MISSION.md references three ventures
check_file_contains "identity/MISSION.md" "AOB" "R1.7a: MISSION.md references AOB"
check_file_contains "identity/MISSION.md" "BuilderBee" "R1.7b: MISSION.md references BuilderBee"
check_file_contains "identity/MISSION.md" "Centaurion" "R1.7c: MISSION.md references Centaurion"

# ============================================================
# R2: Active Inference Loop
# ============================================================
echo ""
echo "═══ R2: Active Inference Loop ═══"

# R2.1: CLAUDE.md defines all 7 loop steps
LOOP_STEPS="SENSE PREDICT COMPARE ROUTE ACT OBSERVE REMEMBER"
for step in $LOOP_STEPS; do
  check_file_contains "CLAUDE.md" "$step" "R2.1: CLAUDE.md contains loop step: $step"
done

# R2.2: Detailed loop file exists
check_file_nonempty "framework/active-inference-loop.md" "R2.2: active-inference-loop.md exists"

# R2.3: Loop maps to PAI Algorithm phases
check_file_contains "framework/active-inference-loop.md" "PAI" "R2.3: Loop references PAI mapping"

# R2.4: REMEMBER step is mandatory
check_file_contains "CLAUDE.md" "mandatory" "R2.4a: CLAUDE.md marks REMEMBER as mandatory"
check_file_contains "framework/active-inference-loop.md" "mandatory" "R2.4b: Loop doc marks REMEMBER as mandatory"

# R2.5: Loop references Routing Gate
check_file_contains "CLAUDE.md" "routing-gate" "R2.5: CLAUDE.md references routing-gate"

# ============================================================
# R3: Routing Gate
# ============================================================
echo ""
echo "═══ R3: Routing Gate ═══"

# R3.1: Routing Gate skill exists with frontmatter
check_file_exists "skills/routing-gate/SKILL.md" "R3.1a: routing-gate SKILL.md exists"
check_file_contains "skills/routing-gate/SKILL.md" "^---" "R3.1b: SKILL.md has YAML frontmatter"
check_file_contains "skills/routing-gate/SKILL.md" "name:" "R3.1c: Frontmatter has name field"
check_file_contains "skills/routing-gate/SKILL.md" "description:" "R3.1d: Frontmatter has description field"

# R3.2: Three classification dimensions
check_file_contains "skills/routing-gate/SKILL.md" "novelty" "R3.2a: Defines novelty dimension"
check_file_contains "skills/routing-gate/SKILL.md" "stakes" "R3.2b: Defines stakes dimension"
check_file_contains "skills/routing-gate/SKILL.md" "reversibility" "R3.2c: Defines reversibility dimension"

# R3.3: Decision rule with thresholds
check_file_contains_exact "skills/routing-gate/SKILL.md" "0.7" "R3.3a: Novelty threshold 0.7"
check_file_contains_exact "skills/routing-gate/SKILL.md" "0.5" "R3.3b: Stakes threshold 0.5"
check_file_contains_exact "skills/routing-gate/SKILL.md" "0.3" "R3.3c: Reversibility threshold 0.3"
check_file_contains "skills/routing-gate/SKILL.md" "STOP" "R3.3d: Decision rule says STOP"

# R3.4: Framework routing-gate doc exists with rubrics
check_file_nonempty "framework/routing-gate.md" "R3.4a: framework/routing-gate.md exists"
check_file_contains "framework/routing-gate.md" "0.0" "R3.4b: Scoring rubrics present"

# R3.5: Instructs to surface to Malik
check_file_contains "skills/routing-gate/SKILL.md" "Malik" "R3.5: Instructs to surface to Malik"

# ============================================================
# R4: Agent Personalities
# ============================================================
echo ""
echo "═══ R4: Agent Personalities ═══"

# R4.1-R4.3: Agent files exist with correct identity
check_file_contains "agents/Cortex.md" "reasoning" "R4.1: Cortex.md identifies as reasoning agent"
check_file_contains "agents/Nova.md" "sensing" "R4.2: Nova.md identifies as sensing agent"
check_file_contains "agents/Daemon.md" "identity root" "R4.3: Daemon.md identifies as identity root"

# R4.4: Each agent has required sections
for agent in Cortex Nova Daemon; do
  check_file_contains "agents/$agent.md" "Identity" "R4.4a: $agent.md has Identity section"
  check_file_contains "agents/$agent.md" "Role" "R4.4b: $agent.md has Role section"
  check_file_contains "agents/$agent.md" "Runtime" "R4.4c: $agent.md has Runtime section"
  check_file_contains "agents/$agent.md" "Principles" "R4.4d: $agent.md has Principles section"
done

# R4.5: CLAUDE.md references Cortex.md
check_file_contains "CLAUDE.md" "agents/Cortex.md" "R4.5: CLAUDE.md references agents/Cortex.md"

# ============================================================
# R5: Framework Coherence
# ============================================================
echo ""
echo "═══ R5: Framework Coherence ═══"

# R5.1: Three Laws doc defines all three
check_file_contains "framework/three-laws.md" "Hierarchy" "R5.1a: three-laws.md defines Hierarchy"
check_file_contains "framework/three-laws.md" "Routing" "R5.1b: three-laws.md defines Routing"
check_file_contains "framework/three-laws.md" "Coupling" "R5.1c: three-laws.md defines Coupling"

# R5.2: Fitness equation doc
check_file_contains "framework/precision-ratio.md" "Predictive Order" "R5.2a: precision-ratio.md has numerator"
check_file_contains "framework/precision-ratio.md" "Thermodynamic Cost" "R5.2b: precision-ratio.md has denominator"

# R5.3: Five sensing layers doc
check_file_contains "framework/five-sensing-layers.md" "L0" "R5.3a: Defines L0"
check_file_contains "framework/five-sensing-layers.md" "L1" "R5.3b: Defines L1"
check_file_contains "framework/five-sensing-layers.md" "L2" "R5.3c: Defines L2"
check_file_contains "framework/five-sensing-layers.md" "L3" "R5.3d: Defines L3"
check_file_contains "framework/five-sensing-layers.md" "L4" "R5.3e: Defines L4"

# R5.4: Cross-references
check_file_contains "framework/three-laws.md" "Routing Gate" "R5.4a: Three Laws references Routing Gate"
check_file_contains "framework/three-laws.md" "Supermemory" "R5.4b: Three Laws references Supermemory"

# R5.5: Markov Blanket maps to Daemon
check_file_nonempty "framework/markov-blanket.md" "R5.5a: markov-blanket.md exists"
check_file_contains "framework/markov-blanket.md" "Daemon" "R5.5b: Markov Blanket maps to Daemon agent"

# ============================================================
# R6: Skills Architecture
# ============================================================
echo ""
echo "═══ R6: Skills Architecture ═══"

# R6.1: All SKILL.md files have YAML frontmatter
SKILLS="centaurion-core routing-gate weekly-review sa-scan gap-analysis"
for skill in $SKILLS; do
  check_file_contains "skills/$skill/SKILL.md" "^---" "R6.1a: skills/$skill/SKILL.md has frontmatter"
  check_file_contains "skills/$skill/SKILL.md" "name:" "R6.1b: skills/$skill/SKILL.md has name"
  check_file_contains "skills/$skill/SKILL.md" "description:" "R6.1c: skills/$skill/SKILL.md has description"
done

# R6.2: Core skill references identity files
check_file_contains "skills/centaurion-core/SKILL.md" "PURPOSE.md" "R6.2a: Core skill references PURPOSE.md"
check_file_contains "skills/centaurion-core/SKILL.md" "MISSION.md" "R6.2b: Core skill references MISSION.md"

# R6.3: At least 5 skills exist
SKILL_COUNT=0
for skill in $SKILLS; do
  if [ -f "$REPO_ROOT/skills/$skill/SKILL.md" ]; then
    SKILL_COUNT=$((SKILL_COUNT + 1))
  fi
done
if [ "$SKILL_COUNT" -ge 5 ]; then
  pass "R6.3: At least 5 skills exist ($SKILL_COUNT found)"
else
  fail "R6.3: Need at least 5 skills, found $SKILL_COUNT"
fi

# R6.4: CLAUDE.md lists available skills
check_file_contains "CLAUDE.md" "skills/centaurion-core" "R6.4a: CLAUDE.md lists centaurion-core skill"
check_file_contains "CLAUDE.md" "skills/routing-gate" "R6.4b: CLAUDE.md lists routing-gate skill"

# ============================================================
# R7: Memory Configuration
# ============================================================
echo ""
echo "═══ R7: Memory Configuration ═══"

# R7.1: Supermemory config with venture containers
check_file_exists "memory/supermemory.json" "R7.1a: supermemory.json exists"
check_file_contains "memory/supermemory.json" "aob" "R7.1b: Has AOB container"
check_file_contains "memory/supermemory.json" "builderbee" "R7.1c: Has BuilderBee container"
check_file_contains "memory/supermemory.json" "centaurion" "R7.1d: Has Centaurion container"

# R7.2: Wiki repos config
check_file_exists "memory/wiki-repos.json" "R7.2a: wiki-repos.json exists"
check_file_contains "memory/wiki-repos.json" "aob-wiki" "R7.2b: References aob-wiki"
check_file_contains "memory/wiki-repos.json" "builderbee-wiki" "R7.2c: References builderbee-wiki"
check_file_contains "memory/wiki-repos.json" "centaurion-wiki" "R7.2d: References centaurion-wiki"

# R7.3: Graphiti config with a recognized lifecycle status.
# Accepts forward progress: planned_month_2 (original) → scaffolded → connected.
# Pinning to "planned" would fail the suite the moment Graphiti is actually built.
check_file_exists "memory/graphiti.json" "R7.3a: graphiti.json exists"
check_file_contains "memory/graphiti.json" "planned_month_2\|scaffolded\|connected" "R7.3b: Graphiti has a recognized status (planned/scaffolded/connected)"

# R7.4: No actual API keys committed
if grep -rq "sm_[a-zA-Z0-9]" "$REPO_ROOT/memory/" 2>/dev/null; then
  fail "R7.4: Real API key found in memory config!"
else
  pass "R7.4: No real API keys committed (REPLACE_WITH_ placeholders used)"
fi

# ============================================================
# R8: Multi-Runtime Support
# ============================================================
echo ""
echo "═══ R8: Multi-Runtime Support ═══"

# R8.1: AGENTS.md exists
check_file_exists "AGENTS.md" "R8.1: AGENTS.md exists at repo root"

# R8.2: AGENTS.md contains Three Laws and loop
check_file_contains "AGENTS.md" "Hierarchy" "R8.2a: AGENTS.md contains Hierarchy Law"
check_file_contains "AGENTS.md" "Routing" "R8.2b: AGENTS.md contains Routing Law"
check_file_contains "AGENTS.md" "Coupling" "R8.2c: AGENTS.md contains Coupling Law"
check_file_contains "AGENTS.md" "SENSE" "R8.2d: AGENTS.md contains Active Inference loop"

# R8.3: Runtime-specific notes
check_file_contains "AGENTS.md" "pi" "R8.3a: AGENTS.md has pi runtime notes"
check_file_contains "AGENTS.md" "OpenClaw" "R8.3b: AGENTS.md has OpenClaw runtime notes"
check_file_contains "AGENTS.md" "Agent Zero" "R8.3c: AGENTS.md has Agent Zero runtime notes"
check_file_contains "AGENTS.md" "Codex" "R8.3d: AGENTS.md has Codex runtime notes"

# ============================================================
# R9: Output & Style
# ============================================================
echo ""
echo "═══ R9: Output & Style ═══"

# R9.1: CLAUDE.md specifies phone-readable output
check_file_contains "CLAUDE.md" "phone" "R9.1: CLAUDE.md specifies phone-readable output"

# R9.2: PREFERENCES.md specifies structured output
check_file_contains "identity/PREFERENCES.md" "table" "R9.2a: PREFERENCES.md mentions structured output"
check_file_contains "identity/PREFERENCES.md" "bullet" "R9.2b: PREFERENCES.md mentions bullets"

# R9.3: CLAUDE.md instructs reasoning transparency
check_file_contains "CLAUDE.md" "tradeoff" "R9.3a: CLAUDE.md instructs surfacing tradeoffs"
check_file_contains "CLAUDE.md" "reasoning" "R9.3b: CLAUDE.md instructs stating reasoning"

# ============================================================
# R10: Structural Integrity
# ============================================================
echo ""
echo "═══ R10: Structural Integrity ═══"

# R10.1: All paths in CLAUDE.md exist
CLAUDE_PATHS=$(grep -oE '(identity|framework|agents|skills|memory|workflows)/[A-Za-z0-9_/-]+\.(md|jsonl?|yaml)' "$REPO_ROOT/CLAUDE.md" 2>/dev/null || true)
R10_1_OK=true
for path in $CLAUDE_PATHS; do
  if [ ! -f "$REPO_ROOT/$path" ]; then
    # Skip intentionally gitignored per-operator/runtime files (e.g. onboarding-state.json,
    # identity/BASELINE-*.md). They exist on the operator's host but are absent by design in
    # fresh clones / CI, so a missing gitignored path is not a broken reference.
    if git -C "$REPO_ROOT" check-ignore -q "$path" 2>/dev/null; then
      continue
    fi
    fail "R10.1: CLAUDE.md references non-existent file: $path"
    R10_1_OK=false
  fi
done
if [ "$R10_1_OK" = true ] && [ -n "$CLAUDE_PATHS" ]; then
  pass "R10.1: All paths referenced in CLAUDE.md exist"
elif [ -z "$CLAUDE_PATHS" ]; then
  fail "R10.1: No file paths found in CLAUDE.md to validate"
fi

# R10.2: All paths in AGENTS.md exist
AGENTS_PATHS=$(grep -oE '(identity|framework|agents|skills|memory|workflows)/[A-Za-z0-9_/-]+\.(md|jsonl?|yaml)' "$REPO_ROOT/AGENTS.md" 2>/dev/null || true)
R10_2_OK=true
for path in $AGENTS_PATHS; do
  if [ ! -f "$REPO_ROOT/$path" ]; then
    # Skip intentionally gitignored per-operator/runtime files (absent by design in CI).
    if git -C "$REPO_ROOT" check-ignore -q "$path" 2>/dev/null; then
      continue
    fi
    fail "R10.2: AGENTS.md references non-existent file: $path"
    R10_2_OK=false
  fi
done
if [ "$R10_2_OK" = true ] && [ -n "$AGENTS_PATHS" ]; then
  pass "R10.2: All paths referenced in AGENTS.md exist"
elif [ -z "$AGENTS_PATHS" ]; then
  pass "R10.2: AGENTS.md uses directory-level references (no broken file links)"
fi

# R10.3: Framework cross-references resolve
FRAMEWORK_REFS=$(grep -ohE '(framework|identity|agents|skills)/[A-Za-z0-9_/-]+\.md' "$REPO_ROOT"/framework/*.md 2>/dev/null | sort -u || true)
R10_3_OK=true
R10_3_COUNT=0
for ref in $FRAMEWORK_REFS; do
  if [ ! -f "$REPO_ROOT/$ref" ]; then
    fail "R10.3: Framework cross-ref broken: $ref"
    R10_3_OK=false
  else
    R10_3_COUNT=$((R10_3_COUNT + 1))
  fi
done
if [ "$R10_3_OK" = true ]; then
  pass "R10.3: All framework cross-references resolve ($R10_3_COUNT checked)"
fi

# R10.4: Skills reference valid framework files
SKILL_REFS=$(grep -ohE 'framework/[A-Za-z0-9_/-]+\.md' "$REPO_ROOT"/skills/*/SKILL.md 2>/dev/null | sort -u || true)
R10_4_OK=true
for ref in $SKILL_REFS; do
  if [ ! -f "$REPO_ROOT/$ref" ]; then
    fail "R10.4: Skill references broken framework file: $ref"
    R10_4_OK=false
  fi
done
if [ "$R10_4_OK" = true ]; then
  pass "R10.4: All skill → framework references resolve"
fi

# R10.5: README.md describes directory structure
check_file_contains "README.md" "identity/" "R10.5a: README mentions identity/"
check_file_contains "README.md" "framework/" "R10.5b: README mentions framework/"
check_file_contains "README.md" "agents/" "R10.5c: README mentions agents/"
check_file_contains "README.md" "skills/" "R10.5d: README mentions skills/"
check_file_contains "README.md" "memory/" "R10.5e: README mentions memory/"

# ============================================================
# Summary
# ============================================================
echo ""
echo "════════════════════════════════════════"
echo "  RESULTS: $PASS passed, $FAIL failed ($TOTAL total)"
echo "════════════════════════════════════════"

if [ "$FAIL" -eq 0 ]; then
  echo "  ✓ ALL REQUIREMENTS PASS"
  exit 0
else
  echo "  ✗ $FAIL REQUIREMENT(S) FAILED"
  exit 1
fi
