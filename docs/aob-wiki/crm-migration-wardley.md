# CRM Migration — Wardley Map

*Companion to [crm-migration.md](crm-migration.md). Linked PRD: `memory/state/work/aob-crm-migration-omega-20260425/PRD.md`. Captured 2026-04-25 by Cortex.*

> **Anchoring axiom (from PRD):** A CRM compresses *intent → response latency*. AOB revenue concentrates in cohort-launch windows. Therefore the migration succeeds when latency is **preserved across a full cohort cycle**, not when *GHL is configured*.

## User need (top of map)

Cohort enrollee receives timely, personalized communication across the journey: **prospect → enrolled → certified facilitator**.

---

## Value chain × evolution

| Component | Evolution | Movement | Action | Notes |
|---|---|---|---|---|
| Cohort enrollee experience *(user need)* | — | — | — | Top of map |
| Cohort gating + certification state machine | **Custom** | Stable | **Build** *(in GHL workflows)* | The AOB-specific moat. Never commodity. |
| Personalized nurture sequences | Product | → Commodity | **Buy** | GHL workflows. Don't re-invent Ontraport DSL. |
| Cohort enrollment forms | Product | Stable | **Buy** | GHL forms. |
| Behavioral triggers (open / click / purchase) | Product | → Commodity | **Buy** | GHL triggers. Map 1:1 from Ontraport. |
| Tags & segments | Product | Stable | **Buy** | GHL tags / custom values. Naming-convention mapping is the work. |
| Contact data store | Product | Stable | **Buy** | GHL contacts. |
| Landing-page hosting | Product | → Commodity | **Buy** | GHL funnels. |
| Payment processing | **Commodity** | Stable | **Buy** | Stripe via GHL. |
| Email send infrastructure | **Commodity** | Stable | **Buy** | GHL native deliverability. |
| **Behavioral-parity validator** (Ontraport ↔ GHL diff via browser-harness) | **Genesis** | ↑ New build | **Build** | Centaurion-shaped — re-usable for future migrations. |
| **Latency observability dashboard** (cross-CRM) | Custom → Genesis | ↑ Build | **Build** | Required by success metric (latency preservation). |
| **Routing-Gate cutover governance** | **Genesis** | ↑ New build | **Build** | PRD Phase C/D requirement. |
| AI-driven personalization (e.g. GHL "AI employees") | Genesis | Watch | **Defer** | Not yet stable; revisit after cutover. |

---

## Strategic plays

1. **Buy the commodity stack wholesale.** The whole point of leaving Ontraport is to stop maintaining a custom-tier capability the market has commoditized. Resist rebuilding Ontraport idiosyncrasies inside GHL workflows.
2. **Build only the three genesis-tier capabilities** — parity validator, latency dashboard, Routing-Gate cutover. These three are what make this migration *Centaurion-shaped* rather than "GHL is configured" (the failure mode the PRD's first-principles section warns against).
3. **Cohort logic is the moat.** It stays Custom. Encode it as portable workflow definitions in GHL, not free-form clicks — so the next CRM migration is cheaper.

---

## Climate (what's moving on the map)

- **Email-marketing platforms** are evolving Custom → Product → **Commodity**. Ontraport's 2015 value prop is now commodity. **GHL is the bet that the bundle is now reliable.**
- **Behavioral triggers** (open / click / purchase) are commoditizing fast — every CRM has them.
- **AI-driven personalization** is in **Genesis**. Directional bet, not foundational.

---

## Doctrine (per phase)

| Phase | Method | Key doctrine |
|---|---|---|
| A — Parity modeling | Agile | Log every mapping decision via Routing Gate. |
| B — Synthetic validation | Iterative | Browser-harness drives both UIs. Synthetic contacts only — no public-facing form changes. |
| C — Window selection | Routed | Always surface to Malik. Hierarchy Law. |
| D — Cutover execution | Waterfall, one-shot | Rollback triggers must be **observable**, not declared. |
| E — Verification | Coupling Law | One full cohort cycle on GHL before Ontraport deactivation. Wiki updated, Supermemory entries written. |

**Always:** transparency (parity report → this wiki, not private docs); Coupling Law over private artifacts.

---

## Coordinate-tagged node set (for Miro overlay)

Use this when placing the map on a [Simplified Wardley template](https://miro.com/miroverse/simplified-wardley-map-template/). Coordinates are normalized 0–1 (x: Genesis → Commodity, y: invisible → visible).

| Node | x | y | Color | Movement |
|---|---|---|---|---|
| Cohort enrollee *(user)* | 0.50 | 1.00 | black | — |
| Cohort gating + certification state | 0.35 | 0.85 | blue (Custom-keep) | stable |
| Personalized nurture sequences | 0.65 | 0.78 | green (Buy) | →0.78 |
| Cohort enrollment forms | 0.62 | 0.72 | green (Buy) | stable |
| Behavioral triggers | 0.68 | 0.62 | green (Buy) | →0.85 |
| Tags & segments | 0.65 | 0.55 | green (Buy) | stable |
| Contact data store | 0.70 | 0.45 | green (Buy) | stable |
| Landing-page hosting | 0.72 | 0.40 | green (Buy) | →0.85 |
| Payment processing (Stripe) | 0.90 | 0.30 | green (Buy) | stable |
| Email send infrastructure | 0.92 | 0.20 | green (Buy) | stable |
| Behavioral-parity validator | 0.08 | 0.55 | red (Build, Genesis) | ↑ →0.30 |
| Latency observability dashboard | 0.20 | 0.65 | red (Build) | ↑ →0.40 |
| Routing-Gate cutover governance | 0.05 | 0.78 | red (Build, Genesis) | stable |
| AI personalization (GHL AI employees) | 0.10 | 0.70 | grey (Defer) | emerging |

---

## Routing-Gate adjustments active here

- **R2:** AOB scope drift → flag for review (BASELINE-INTEGRAL R2 — AOB overflow auto-surface).
- **R3:** Daily $ visibility → cutover impacts revenue, surface to Malik.
- **R7:** Protect deep-work hours during cutover window.

## Risks (red-team scoped)

- VPS2 SPOF during cutover (red-team #1).
- Self-improving GHL skills drifting between audits (red-team #3).
- Memory-fabric divergence — Supermemory and AOB wiki disagreeing on which sequences have migrated (red-team #4).

---

## Next actions (linked to PRD phases)

- [ ] Phase A: export Ontraport sequences/triggers/tags/segments to `docs/aob-wiki/crm-migration/sources/`
- [ ] Phase A: build behavioral-parity table (Ontraport trigger → GHL equivalent → expected delta → mitigation)
- [ ] Phase A: define rollback triggers as observable thresholds
- [ ] Phase B: stand up browser-harness skill against synthetic contacts in both systems
- [ ] Phase B: ship behavioral-parity report to this wiki
- [ ] Phase C: surface cutover-window proposal to Malik (≤ 5 lines, phone-readable)
