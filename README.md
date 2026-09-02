# AI-Native SDLC

This repository turns [Anthropic's AI-Native SDLC playbook](https://claude.com/blog/the-ai-native-sdlc-playbook) into a repository-native operating model and a Claude Code plugin.

Code generation is no longer the only constraint on delivery. Planning, policy application, verification, review, release authorization, and production learning must also run at agent speed without giving agents authority that belongs to people. This project makes every handoff explicit, version controlled, and reviewable.

The operating rule is simple: agents generate, investigate, implement, and verify; humans approve decisions that require judgment. Each accepted artifact starts the next stage, and Git records the request, result, and approval.

## The six-stage loop

| Stage | Skill that drives it | Purpose | Committed artifact | Human gate |
| --- | --- | --- | --- | --- |
| Plan | `sdlc-plan` | Capture the originator's problem, outcome, and constraints | `.sdlc/<slug>/intent.md` | Product owner accepts the intent |
| Design | `sdlc-design` | Turn accepted intent into requirements and a policy-aware design | `.sdlc/<slug>/spec.md` | Product owner approves; technical owner joins for high risk |
| Build | `sdlc-build` | Agree the implementation route before changing code | `.sdlc/<slug>/plan.md`, then code and tests | Engineer approves the plan |
| Test | `sdlc-test` | Produce deterministic evidence and regress the agent configuration | Test output, eval results, and PR checks | Required checks pass; code owner assesses residual risk |
| Deploy | `sdlc-deploy` | Review consistently and stop at the production boundary | PR, review findings, and release record | Code owner and named release authority approve |
| Maintain | `sdlc-maintain` | Detect drift, diagnose it, and feed learning back into Plan | Incident record or new `.sdlc/<slug>/intent.md` | Service owner triages the finding |

Two subagents serve the loop: `sdlc-reviewer` runs the `REVIEW.md` passes in Stage 5,
and `sdlc-diagnostician` turns a Stage 6 control-band breach into a draft `intent.md`.

You do not invoke the skills by name. Describe the work and the matching stage skill loads
itself; the hooks keep the loop asserted from then on.

## Install

Clone the repository and load the plugin directly while developing it:

```sh
git clone https://github.com/hieuvu7/ai-native-sdlc.git
cd ai-native-sdlc
claude --plugin-dir ./plugins/ai-sdlc
```

Or add the repository as a Claude Code marketplace and install the plugin:

```text
/plugin marketplace add hieuvu7/ai-native-sdlc
/plugin install ai-sdlc@ai-native-sdlc
```

## Quickstart

From the target repository, initialize the workflow:

```text
/ai-sdlc-init
```

Then just describe the problem. No workflow keyword is needed; `sdlc-plan` picks it up:

```text
Customers keep calling support to ask where their claim is.
We should show them the status themselves.
```

The workflow creates `.sdlc/<slug>/`, writes `intent.md`, and pauses. After acceptance it writes `spec.md`, then `plan.md`, then implements and verifies the change. It never treats its own output as human approval.

Check the current artifact and next gate at any time:

```text
/ai-sdlc-status
```

## Stays on after install

- `/ai-sdlc-init` creates `.sdlc/`; its presence is the workflow's ON switch.
- `.sdlc/OPTOUT` is the OFF switch.
- Plugin hooks stay inert in repositories without `.sdlc/`.
- Activation is one-time; no re-prompting is needed in later sessions.

## Repository map

```text
.
├── README.md
├── docs/
│   ├── PLAYBOOK.md       # Stage-by-stage operating model and artifact contract
│   ├── GOVERNANCE.md     # Enforceable controls and threat model
│   ├── METRICS.md        # Process health signals and computations
│   └── ADOPTION.md       # Three-phase rollout
├── plugins/ai-sdlc/
│   ├── .claude-plugin/   # Plugin manifest
│   ├── commands/         # Initialization and status commands
│   ├── skills/           # Executable stage procedures
│   ├── agents/           # Bounded reviewers and diagnosticians
│   ├── hooks/            # Artifact and production gates
│   └── templates/        # Artifact and policy templates
└── .claude-plugin/       # Marketplace catalog
```

## Documentation

- [Playbook](docs/PLAYBOOK.md): the thesis, loop, artifact templates, ownership, and gates.
- [Governance](docs/GOVERNANCE.md): controls that make policy executable.
- [Metrics](docs/METRICS.md): leading and lagging process indicators.
- [Adoption](docs/ADOPTION.md): a safe rollout from one volunteer to the organization.

## What this is not

- It is not permission for an agent to merge, approve, or deploy its own work.
- It is not a replacement for product judgment, code ownership, incident command, or regulatory accountability.
- It is not a new system of record forced on every team; existing Jira, ServiceNow, design, and change-management systems can remain authoritative when commits link both ways.
- It is not a promise that Markdown makes weak requirements good. Artifacts are useful only when reviewers reject ambiguity.
- It is not a scorecard for ranking developers by agent usage, output, or speed.
- It is not a reason to remove deterministic tests, static analysis, branch protection, sandboxing, or rollback practice.

Start with the artifacts, prove that the gates improve decisions, and automate only the paths the team can explain and audit.
