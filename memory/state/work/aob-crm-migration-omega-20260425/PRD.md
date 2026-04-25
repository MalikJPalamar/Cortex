---
task: AOB Ontraport→GHL migration, executed via Omega centaur
slug: aob-crm-migration-omega-20260425
venture: aob
effort: deep
phase: sense
progress: "0/22"
started: 2026-04-25T00:00:00Z
updated: 2026-04-25T00:00:00Z
---

## Context

AOB is migrating its CRM from Ontraport to GoHighLevel (see
`docs/aob-wiki/crm-migration.md`). This PRD reframes that migration
under the **Omega paradigm**: Centaurion's identity layer governing
Hermes's self-improving engine, with browser-harness as the actuation
hand and a 6-layer memory fabric for state.

**First-principles framing (binding constraint):**
A CRM exists to compress intent→response latency. AOB revenue
concentrates in cohort-launch windows. Therefore the migration's
success metric is *latency preservation across a full cohort cycle*,
not "GHL is configured."

**Why Omega-shaped, not just bash-scripted:**
- Migration is multi-week, cross-system, with semantic drift risk
  (Ontraport triggers ≠ GHL triggers 1:1). It needs *governed*
  execution — Routing Gate must intercept any cutover action that
  touches live AOB contacts during a launch window (A3).
- Behavioral parity validation requires browser-driving both UIs
  (Ontraport export UI, GHL workflow editor). Browser-harness as a
  Hermes tool is the natural vehicle.
- Long-running reconciliation needs persistent memory across sessions
  — Hermes SQLite + Supermemory + AOB wiki updates.

**Constraints:**
- No cutover during a certification cohort launch window.
- Must run *behaviorally* parallel — synthetic contacts only — before
  any public-facing form points at GHL. No duplicate sends to real
  contacts.
- Rollback triggers must be defined and observable, not just declared.

**Dependencies:**
- Omega bridge live on VPS2 (Sprint 2 target).
- Routing Gate out-of-band enforcement (red-team mitigation #1) —
  required before any Hermes-driven write to GHL prod.
- AOB wiki (`docs/aob-wiki/`) is the canonical record of campaign logic.

**Risks (from red-team, scoped to this migration):**
- VPS2 SPOF during cutover (red-team #1).
- Self-improving GHL skills drifting between audits (red-team #3).
- Memory fabric divergence — Supermemory and AOB wiki disagreeing on
  which sequences have been migrated (red-team #4).

## Success Criteria

**Phase A — Parity Modeling (Centaurion-governed)**
- [ ] Export every Ontraport sequence, trigger, tag, and segment to
      versioned markdown in `docs/aob-wiki/crm-migration/sources/`
- [ ] Build a behavioral-parity table: Ontraport trigger → GHL
      equivalent → expected delta → mitigation
- [ ] Routing Gate classification logged for every mapping decision
      (novel/high-stakes mappings surfaced to Malik)
- [ ] Define rollback triggers — specific, observable thresholds
      (e.g., "intent→response p95 latency > Ontraport baseline + X%
      for 24h → revert public forms to Ontraport")

**Phase B — Synthetic Validation (Hermes + browser-harness)**
- [ ] Create N synthetic contacts in both systems (no public-facing
      form changes)
- [ ] Browser-harness skill drives Ontraport UI to trigger each
      sequence on synthetic contacts; logs outbound emails
- [ ] Browser-harness skill drives GHL UI to trigger each migrated
      workflow on synthetic contacts; logs outbound emails
- [ ] Diff outbound emails per-sequence: subject, body tokens, timing,
      branching. Behavioral-parity report committed to AOB wiki.
- [ ] Personalization tokens verified (Ontraport merge fields → GHL
      custom values mapping holds)

**Phase C — Cutover Window Selection (Routed to Malik)**
- [ ] Identify next inter-cohort gap of ≥ N days
- [ ] Surface to Malik with: window dates, parity report, rollback
      triggers, expected blast radius — under 5 lines, phone-readable
- [ ] Cutover scheduled only after explicit Malik approval (Hierarchy
      Law)

**Phase D — Cutover Execution (Routed, governed)**
- [ ] Public-facing forms repointed to GHL endpoints
- [ ] Ontraport sequences set to log-only (no sends), kept active
      for 60 days
- [ ] Both systems instrumented; latency dashboard live
- [ ] Daemon/cron tail watches rollback-trigger metrics; auto-pages
      Malik on threshold breach

**Phase E — Verification & Memory Update (Coupling Law)**
- [ ] One full cohort cycle (enrollment → onboarding → first lesson)
      completed entirely on GHL
- [ ] Latency p50/p95 ≤ Ontraport baseline (or documented why higher
      is acceptable)
- [ ] AOB wiki updated: `crm-migration.md` status flipped to
      `complete`, baseline metrics archived
- [ ] Supermemory entries written (tagged `aob`, `crm`, `omega`) for
      each non-trivial decision
- [ ] Ontraport deactivated only after full-cycle verification +
      Malik sign-off

## Decisions

- 2026-04-25: Migration reframed under Omega paradigm. Rationale:
  multi-system, semantic-drift-prone, cohort-timing-sensitive →
  fits Routing Gate's intended jurisdiction precisely.
- 2026-04-25: Success metric set to *latency preservation*, not
  *configuration completeness*. Derived from first-principles axiom
  A1 (CRM = intent→response latency compressor).
- 2026-04-25: Rollback triggers are a binding criterion, not a
  documentation item. Phase A blocks Phase B until they exist.
- 2026-04-25: No public-form repoint until Phase B parity report is
  signed off. Behavioral parallel on synthetic contacts only.

## Verification

(Populated during OBSERVE phase — evidence per criterion.)

## Routing Notes

- Phase A (modeling, exports, mapping): auto-execute, log decisions.
- Phase B (browser-harness against AOB Ontraport account): treat as
  read/write on production data → confirm with Malik before each
  synthetic-contact batch that touches the Ontraport account.
- Phase C (window selection): always surface to Malik.
- Phase D (cutover): high stakes, low reversibility → STOP, route.
- Phase E (Ontraport deactivation): one-way door → route.
