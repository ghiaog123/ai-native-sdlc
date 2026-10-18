# ai-sdlc

A six-stage software development lifecycle for coding agents, where every stage
commits one Markdown artifact and stops at a human gate.

Plan writes `intent.md` — the problem and the outcome, from an interview with
whoever asked. Design turns an accepted intent into `spec.md`. Build reviews and
then implements `plan.md`. Test runs the project's real checks and quotes their
output rather than claiming they passed. Deploy runs the review passes and posts
ranked findings for a human to approve. Maintain watches control bands and files
the next intent when one breaks.

Nothing here replaces judgment. Agents do the synthesis, the implementation, the
verification and the triage; a person decides what to build, what risk to accept
and what ships. Git records who asked, what the agent produced and who approved.

## Install

```
/plugin install ai-sdlc --marketplace ghiaog123/ai-native-sdlc
```

Then run `/ai-sdlc-init` in a repository to scaffold it.

## What it installs

Eight skills: the six stages, plus `/ai-sdlc-init` to scaffold a repository and
`/ai-sdlc-status` to report which changes are waiting on which person.

Two read-only subagents: a pull-request reviewer that applies the project's
`REVIEW.md`, and a diagnostician that investigates a control-band breach without
touching production.

Four hooks, all of them inert unless the repository has a `.sdlc/` directory, so
installing this plugin changes nothing until a project opts in:

- `artifact-gate.sh` refuses a source write that no approved `plan.md` covers, and
  keeps a change declared low-risk away from governance-sensitive paths such as
  `CLAUDE.md`, `REVIEW.md` and CI workflow files.
- `prod-guard.sh` asks for explicit human authorization on deploy and teardown
  command shapes. It is a second, weaker line — IAM, branch protection and deploy
  approvals remain the real controls.
- `session-context.sh` and `prompt-nudge.sh` report where each in-flight change
  sits, derived from committed artifacts rather than stored state.

Templates for every artifact the loop produces, including `REVIEW.md` and
`bands.yaml`.

## What it does not do

It never merges, never deploys, and never treats an agent's approval as a
person's. It will not bypass branch protection, and it cannot: the gates it adds
sit beside your existing controls rather than replacing them.

## Run the checks

```bash
bash hooks/test-artifact-gate.sh
bash hooks/test-sdlc-state.sh
```

## Both runtimes

The same source runs on Claude Code and on Codex. Agent definitions ship as `.md`
and `.toml` kept in step, and project memory is written to `CLAUDE.md` or
`AGENTS.md` from one template so the two cannot drift.

Requires bash, git and python3. Nothing else.

## Documentation and license

The method, the threat model behind each control, the metrics and how each one
gets gamed, and a three-phase rollout are documented in the project repository at
<https://github.com/ghiaog123/ai-native-sdlc>.

This implements the method described in Anthropic's AI-Native SDLC playbook. It
is an independent community implementation, not an Anthropic product, and is
neither affiliated with nor endorsed by Anthropic.

MIT licensed.
