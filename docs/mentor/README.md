# `docs/mentor/` — mentor messages from the hands-on cadence

Each file here is one scaffold-and-mentor turn from Phase 2's hands-on cadence (see [`feedback_working_style`](../../) memory and [the Phase 2 restart spec](../superpowers/specs/2026-05-13-phase2-restart-design.md)).

## Why these exist
The cadence is: Claude scaffolds a `.tf` file with `[D#]` decision markers and sends a mentor message explaining the decisions. Brian fills in values, runs terraform, drafts the service doc. The mentor message itself isn't a service doc — it's the *reasoning at the moment of decision*, including alternatives discussed and the recommendation Brian acted on (or didn't).

Service docs (`docs/services/*.md`) describe the system as it ended up. Mentor messages capture how we got there.

## Naming
`m{module}-s{step}-{topic}.md` — e.g. `m1-s1-locals.md` is Module 1, Step 1, scaffolding locals.

## How to use them
- During a step: this is the message you're working through right now.
- After a step: cross-reference when writing the corresponding service doc or ADR. Lift the "alternatives considered" bits directly.
- Later sessions / other devices: open the latest file to see where the cadence left off.

## Index
- [m1-s1-locals.md](m1-s1-locals.md) — Module 1 Step 1: foundational locals (project name, env, region, tags, RG split)
