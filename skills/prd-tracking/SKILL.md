---
name: prd-tracking
description: Product Requirements Document tracking for every non-trivial task. Creates structured PRDs with success criteria, tracks progress, captures decisions and verification. USE WHEN starting any task that has more than 3 steps or touches multiple files.
---

# PRD Tracking — Task Documentation System

Every non-trivial task gets a PRD. The PRD is the single source of truth for what's being built, why, and whether it succeeded.

## When to Create a PRD

- Task has more than 3 steps
- Task touches multiple files or systems
- Task has dependencies or risks
- Task is for a client (BuilderBee)
- Task affects production systems

Do NOT create PRDs for: quick questions, single-file edits, lookups.

## PRD Format

Create at `memory/state/work/{slug}/PRD.md`:

```markdown
---
task: [Brief deliverable, max 60 chars]
slug: [kebab-case-with-timestamp, e.g., aob-crm-migration-20260425]
venture: [aob | builderbee | centaurion]
effort: [standard | extended | advanced | deep]
phase: [sense | predict | compare | route | act | observe | remember | complete]
progress: "0/N"
started: [ISO 8601]
updated: [ISO 8601]
---

## Context
[What was requested, why, constraints, dependencies, risks]

## Success Criteria
- [ ] [Criterion 1 — binary, testable, 8-12 words]
- [ ] [Criterion 2]
- [ ] [Criterion 3]

## Decisions
[Timestamped log of non-obvious choices]
- [timestamp] [decision]: [rationale]

## Verification
[Evidence collected during OBSERVE phase]
```

## Effort Levels

| Level | Criteria Count | When |
|-------|---------------|------|
| Standard | 4-8 | Most tasks |
| Extended | 8-16 | Multi-step workflows |
| Advanced | 16-24 | System changes, migrations |
| Deep | 24+ | Architecture decisions, client projects |

## Lifecycle

### 1. SENSE → Create PRD
When you receive a task, create the PRD immediately. Fill in Context and Success Criteria.

### 2. PREDICT → Estimate
Add effort level and initial phase. State your confidence.

### 3. ROUTE → Classify
Apply Routing Gate. If surfaced to Malik, note it in Decisions.

### 4. ACT → Execute
Work through criteria. Check each one as completed. Update `progress` in frontmatter.

### 5. OBSERVE → Verify
For each criterion: verify it independently. Add evidence to Verification section.

### 6. REMEMBER → Complete
Set phase to `complete`. Update `progress` to final count. Log outcome in ratings.

## PRD Commands

**Create:** "Create a PRD for [task description]"
**Status:** "What's the status of [slug]?"
**List:** "List active PRDs"
**Complete:** "Mark [slug] as complete"

## Active PRD Discovery

On session start, check `memory/state/work/` for PRDs where phase ≠ complete. Surface them:
"You have N active PRDs: [list slugs and progress]"

## Example

```markdown
---
task: Migrate AOB email sequences from Ontraport to GHL
slug: aob-email-migration-20260425
venture: aob
effort: advanced
phase: act
progress: "3/8"
started: 2026-04-25T10:00:00Z
updated: 2026-04-25T14:30:00Z
---

## Context
AOB needs email sequences migrated from Ontraport to GHL as part of CRM migration.
8 active sequences, ~45 emails total. Must maintain trigger logic and personalization.

## Success Criteria
- [x] Export all Ontraport sequences to markdown
- [x] Map Ontraport triggers to GHL workflow equivalents
- [x] Create GHL workflows for top 3 sequences (by volume)
- [ ] Create GHL workflows for remaining 5 sequences
- [ ] Test all triggers with test contact
- [ ] Verify personalization tokens work
- [ ] Run parallel for 7 days (both systems active)
- [ ] Deactivate Ontraport sequences after parallel period

## Decisions
- 2026-04-25T10:15Z: Start with highest-volume sequences first (Welcome, Cert Inquiry, Breathe The World)
- 2026-04-25T12:00Z: GHL doesn't support Ontraport's conditional merge fields — using custom values instead

## Verification
- [x] Welcome sequence: sent test email, personalization correct, trigger fires on contact create
- [x] Cert Inquiry: 3-email sequence verified, delay timings match Ontraport
```

## Routing

PRD creation is low-stakes, reversible → auto-execute.
PRD completion/verification with client impact → flag for review.

## State Directory

```
memory/state/work/
├── aob-email-migration-20260425/
│   └── PRD.md
├── bb-client-xyz-onboarding-20260420/
│   └── PRD.md
└── centaurion-omega-integration-20260425/
    └── PRD.md
```
