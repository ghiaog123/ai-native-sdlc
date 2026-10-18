# Review findings: [change name]

<!--
One file per change, at `.sdlc/<slug>/review-findings.md`. Append a round; never
rewrite an earlier one. This file is the review's memory: the round counter that
enforces the cap, the SHA that makes the next round diff-only, the record that
stops a finding being posted twice, and the evidence behind the review metrics in
`docs/METRICS.md`.
-->

Reviewer: [sdlc-reviewer | codex-plan-review]. Depth: [Quick | Standard | Deep].
Round cap: 3.

## Round 1 — Plan — [plan.md SHA or `uncommitted`]

Passes run: Plan.

Scope: whole `plan.md`.

`.sdlc/[slug]/plan.md:[line] — Important — [concrete failure] — [specific fix] — Response: pending`

<!--
Severity is defined in `REVIEW.md`: Important, Minor, Nit, Pre-existing.
Response is set by the author when the round closes, and is one of:
  fixed        the finding was real and the code or plan changed
  wrong        the finding was not real
  intentional  real, but the behaviour is deliberate; say where that is recorded
  no-impact    real but not worth changing
`pending` is only valid inside the round currently open.
-->

## Round 2 — Code — [reviewed SHA]

Passes run: Bugs, Security, Compliance.

Scope: diff from [previous round SHA] to [this SHA]. Rounds after the first review
only the new diff, not the whole change.

Already reported in an earlier round, not repeated here: [count].

`path/to/file:line — Important — [concrete failure] — [specific fix] — Response: fixed`
`path/to/file:line — Pre-existing — [concrete failure] — [specific fix] — Response: no-impact`

## Pre-existing

<!--
Findings in code this change did not introduce. They do not block merge, but they
are never silently dropped: list every one here so the responsible human decides.
A Pre-existing finding that is a security defect is reported under Security and
blocks merge like any other Important finding — the tag changes who is answerable,
not whether the change ships.
-->

| Finding | Where | Decision |
| --- | --- | --- |
| [failure] | `path:line` | [fix now \| backlog ref \| accepted, reason] |

## Recurring

<!--
A finding class that has now appeared in two or more changes must be encoded
somewhere that prevents the third occurrence. `sdlc-deploy` will not pass its exit
gate while a row here has no encoding. One row per class, not per instance.
-->

| Class | Changes seen in | Encoded as |
| --- | --- | --- |
| [bug class, not one line] | `[slug]`, `[slug]` | [CLAUDE.md line \| lint rule \| REVIEW.md rule] |

## Round summary

| Round | Stage | Findings posted | Suppressed as duplicates | Verifier rejected |
| --- | --- | --- | --- | --- |
| 1 | Plan | [n] | 0 | [n] |
| 2 | Code | [n] | [n] | [n] |

<!--
When a round would be number 4, the reviewer stops reviewing and asks the author to
reconsider the approach against `plan.md` instead of fixing findings one by one.
Record that here and go back to the plan; do not open round 4.
-->
