---
name: sdlc-build
description: Convert an accepted .sdlc/feature-slug/spec.md into an engineer-approved plan.md and then implement it in the accepted order. Do NOT use for unapproved specifications, independent architecture review, test sign-off, PR review, merging, deployment, or production monitoring.
---

# SDLC Build

Run Stage 3 of 6 in the AI-Native SDLC playbook described in `docs/PLAYBOOK.md`.

## Purpose

Work in two distinct phases: create an approved engineering plan, then implement
the approved plan.

`plan.md` is the contract for implementation. Do not treat it as optional notes.

## Entry gate

Locate `.sdlc/<slug>/spec.md` and read it completely.

Proceed only when the spec exists and declares `Status: accepted`.

If the spec is absent, draft, or unapproved, route to `sdlc-design` and stop.

Do not begin code changes during Phase A.

## Phase A: interview and plan

1. Read the accepted spec, including requirements, non-goals, concerns, and
   verification strategy.
2. Interview the engineer about the proposed approach.
3. Ask which tools or libraries the engineer expects to use and why.
4. Ask for every file expected to change, be added, or be removed.
5. Ask for the implementation order and dependencies between steps.
6. Ask which risks, migrations, compatibility concerns, or rollback concerns exist.
7. Ask how the implementation will prove every requirement and non-goal boundary.
8. Write `.sdlc/<slug>/plan.md` using the required template.
9. Show the full plan to the engineer.
10. Stop for explicit approval before any coding begins.

## Required artifact

Write this plan structure verbatim. Replace only bracketed content with the
engineer's confirmed approach.

```markdown
# Plan: [feature name] (from spec.md [date])

## Files that change
[list of affected files]

## Order of work
[numbered steps]

## Risks
[potential issues]

## Proof
[test coverage description]
```

In **Proof**, describe verification coverage rather than writing test code. For
example, name the unit tests and integration tests that will establish correctness.

List expected files precisely enough that reviewers can compare plan to changes.

## Phase A exit gate

After showing the plan, stop and ask exactly:

> Engineer, does this plan match your approach?

Accept only explicit engineer approval. Do not treat a request to continue as
approval, and do not implement while approval is pending.

If the engineer corrects the plan, revise it and repeat the gate.

## Phase B: implement

Begin Phase B only after explicit approval of `plan.md`.

1. Read and follow the project's `CLAUDE.md` before touching implementation.
2. Use `CLAUDE.md` as project memory and instructions.
3. Apply available skills as policy rather than bypassing them.
4. Respect hooks as guardrails; do not evade or disable them.
5. Use parallel sessions only for genuinely independent work when available and
   permitted by project instructions.
6. Implement the plan in its accepted order.
7. Preserve the spec's non-goals and unresolved concerns.
8. Record each actual deviation in `plan.md` as it happens, including why it was
   necessary and how it affects proof or risk.
9. Do not silently change the chosen approach, file set, order, or verification.

If a deviation invalidates the plan's contract, pause and seek engineer direction
before continuing.

Do not claim that tests pass in this stage unless tests have actually been run;
formal verification is Stage 4.

## Phase B exit gate

When the code exists and deviations are recorded, stop and ask exactly:

> Is the implementation complete per the plan?

Move to testing only after confirmation.

If the engineer says no or identifies incomplete work, return to the accepted plan
and complete or revise the recorded work before asking again.

## Handoff

Hand off `plan.md` and the implemented code to `sdlc-test`.

Include actual deviations and their recorded locations in `plan.md`.

Do not hand off a plan without code or code without its plan.
