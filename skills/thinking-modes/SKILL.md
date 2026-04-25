---
name: thinking-modes
description: Seven cognitive modes for deep analysis. USE WHEN a task requires structured thinking beyond default reasoning — strategy, risk assessment, adversarial review, or multi-perspective analysis.
---

# Thinking Modes — Cognitive Analysis Pack

Invoke a specific thinking mode by name. Each mode produces a structured output format.

## Mode 1: First Principles

Decompose a problem to its fundamental truths, then rebuild from there.

**Invoke:** "Apply first principles to [topic]"

**Procedure:**
1. State the conventional assumption about this topic
2. Ask "Why?" repeatedly until you reach irreducible truths
3. List the axioms — what is definitely true regardless of convention?
4. Rebuild: what conclusions follow from ONLY the axioms?
5. Compare: how does the first-principles answer differ from the conventional one?

**Output format:**
```
CONVENTIONAL ASSUMPTION: [what people assume]
DECOMPOSITION:
  Why? → [reason 1]
  Why? → [reason 2]
  Why? → [axiom reached]
AXIOMS:
  1. [irreducible truth]
  2. [irreducible truth]
REBUILD:
  From axioms → [new conclusion]
DELTA: [how this differs from convention]
```

**Example:** "Apply first principles to AOB's CRM migration."
- Conventional: migrate Ontraport → GHL because everyone's doing it
- Axiom: CRM exists to reduce friction between customer intent and business response
- Rebuild: evaluate by friction-reduction, not feature lists

---

## Mode 2: Red Team

Attack your own plan. Find every way it can fail before it does.

**Invoke:** "Red team [plan/proposal]"

**Procedure:**
1. State the plan clearly (1-2 sentences)
2. Assume an adversarial mindset — you WANT this to fail
3. Identify 5-7 failure modes across: technical, human, market, timing, resource
4. Rate each: probability (1-5) × impact (1-5) = risk score
5. For the top 3 risks: propose a mitigation

**Output format:**
```
PLAN: [the plan being attacked]

FAILURE MODES:
| # | Failure | Category | Prob | Impact | Risk |
|---|---------|----------|------|--------|------|
| 1 | [mode]  | [cat]    | 3    | 5      | 15   |

TOP 3 MITIGATIONS:
1. [risk] → [mitigation]
2. [risk] → [mitigation]
3. [risk] → [mitigation]

VERDICT: [proceed / proceed with mitigations / reconsider]
```

---

## Mode 3: Council of Advisors

Simulate multiple expert perspectives on a decision.

**Invoke:** "Convene the council on [decision]"

**Default council:** Strategist, Operator, Skeptic, Customer, Financier
**Custom council:** "Convene [role1], [role2], [role3] on [decision]"

**Procedure:**
1. State the decision
2. Each advisor gives their perspective (2-3 sentences)
3. Identify where advisors agree (consensus) and disagree (tension)
4. Synthesize: what's the decision that addresses the most tensions?

**Output format:**
```
DECISION: [what's being decided]

ADVISORS:
  Strategist: [perspective]
  Operator: [perspective]
  Skeptic: [perspective]
  Customer: [perspective]
  Financier: [perspective]

CONSENSUS: [what they agree on]
TENSIONS: [where they disagree]
SYNTHESIS: [the decision that addresses tensions]
```

---

## Mode 4: Premortem

It's 6 months from now and this project has failed. Why?

**Invoke:** "Premortem on [project]"

**Procedure:**
1. Assume the project has failed spectacularly
2. Write the postmortem from the future — what went wrong?
3. Identify the 3 most likely root causes
4. For each: what early warning sign would have been visible?
5. What can we do NOW to watch for those signals?

**Output format:**
```
PROJECT: [name]
FAILURE DATE: [6 months from now]
HEADLINE: "[project] failed because..."

ROOT CAUSES:
1. [cause] — early warning: [signal]
2. [cause] — early warning: [signal]
3. [cause] — early warning: [signal]

TRIPWIRES TO SET NOW:
- [ ] [monitoring action for signal 1]
- [ ] [monitoring action for signal 2]
- [ ] [monitoring action for signal 3]
```

---

## Mode 5: Inversion

Instead of asking "how do I succeed?", ask "how would I guarantee failure?" Then avoid those things.

**Invoke:** "Invert [goal]"

**Procedure:**
1. State the goal
2. List 5-7 ways to guarantee failure at this goal
3. Invert each: what's the opposite behavior?
4. Rank by leverage — which inversions have the highest impact?

**Output format:**
```
GOAL: [what you want]

TO GUARANTEE FAILURE:        TO SUCCEED (INVERSION):
1. [failure behavior]    →   [success behavior]
2. [failure behavior]    →   [success behavior]

HIGHEST LEVERAGE: [top 2-3 inversions to focus on]
```

---

## Mode 6: Wardley Map

Position components on the evolution axis to find strategic moves.

**Invoke:** "Wardley map [domain/system]"

**Procedure:**
1. Identify the user need at the top
2. List the value chain (what components serve that need?)
3. Position each on evolution: Genesis → Custom → Product → Commodity
4. Identify movements: what's evolving? What's being commoditized?
5. Strategic play: build custom where you differentiate, buy commodity where you don't

**Output format:**
```
USER NEED: [top-level need]

VALUE CHAIN:
| Component | Evolution | Movement | Action |
|-----------|-----------|----------|--------|
| [comp]    | Custom    | → Product| Buy    |
| [comp]    | Genesis   | Stable   | Build  |

STRATEGIC PLAY: [what to build vs buy vs partner]
```

---

## Mode 7: OODA Loop

Boyd's Observe-Orient-Decide-Act for rapid competitive response.

**Invoke:** "OODA on [situation]"

**Procedure:**
1. **Observe:** What's happening? Raw data, no interpretation.
2. **Orient:** What does it mean? Filter through mental models, culture, experience.
3. **Decide:** What's the hypothesis? What's the best response?
4. **Act:** What's the concrete next action? (One action, not a plan.)

**Output format:**
```
OBSERVE: [raw facts]
ORIENT: [interpretation through models]
DECIDE: [chosen response]
ACT: [single concrete next action]
CYCLE TIME: [how fast can we loop again?]
```

---

## Routing

All thinking modes are low-stakes, highly reversible → auto-execute. The output is analysis, not action. Action requires separate routing through the Routing Gate.
