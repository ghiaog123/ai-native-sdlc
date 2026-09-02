---
description: Report every in-flight SDLC change, its furthest stage, repository state, and next human gate.
---

1. Locate `.sdlc/`. If it is absent, report that the loop has not been initialized and stop.
2. For every direct child slug directory in `.sdlc/`, inspect artifact existence: `intent.md`, `spec.md`, and `plan.md`; also inspect any implementation, review finding, deployment, and band-breach references named in the artifact text.
3. Assign the furthest completed stage: Plan when `intent.md` exists, Design when `spec.md` exists, Build when `plan.md` is committed, Review when review evidence exists, Deploy when deployment evidence exists, and Maintain when a band-breach follow-up exists. Do not infer completion from a directory name alone.
4. For each slug, use Git to state whether its artifacts and referenced implementation are committed, dirty, or untracked. Show the next required human gate: accept intent, accept spec, accept plan, review findings, authorize deploy, or accept follow-up intent.
5. Flag stalls explicitly: any artifact that is uncommitted; a `spec.md` whose modification time is older than referenced code; and a `plan.md` that records deviations (look for a `## Deviations` section or unchecked deviation items).
6. Print a compact table with slug, artifacts, furthest stage, Git state, next human gate, and stalls. End with the exact files or decisions needed to move each stalled change forward.
