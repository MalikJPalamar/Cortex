# CRM Migration — Ontraport to GoHighLevel

## Overview

AOB is migrating its CRM from Ontraport to GoHighLevel (GHL) to consolidate tools, reduce costs, and unlock automation capabilities that Ontraport cannot support.

> **See also:** [CRM Migration — Wardley Map](crm-migration-wardley.md) for the strategic build/buy decisions framing this migration. Linked PRD: `memory/state/work/aob-crm-migration-omega-20260425/PRD.md`.

## Why Migrate

- **Cost:** Ontraport pricing scales poorly with contact volume
- **Automation:** GHL offers native workflow automation, landing pages, and funnel builders in one platform
- **Consistency:** BuilderBee already uses GHL — shared platform means shared knowledge and templates
- **API access:** GHL's API enables Centaurion integration for automated monitoring

## Migration Scope

| Component | From (Ontraport) | To (GHL) | Status |
|-----------|-------------------|-----------|--------|
| Contact database | Ontraport contacts | GHL contacts | Planned |
| Email sequences | Ontraport campaigns | GHL workflows | Planned |
| Landing pages | Ontraport pages | GHL funnels | Planned |
| Payment processing | Ontraport + Stripe | GHL + Stripe | Planned |
| Tags and segments | Ontraport tags | GHL tags | Planned |

## Risks

- Data loss during contact export/import
- Broken email sequences if triggers don't map 1:1
- Downtime affecting active certification cohorts
- Team retraining on new platform

## Rollback Plan

Keep Ontraport active for 60 days post-migration. Run parallel for first 30 days to validate GHL workflows match expected behavior.
