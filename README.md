# AI-Native SDLC — Anthropic Playbook

**An AI-native software development lifecycle you can actually run** — six stages, one committed Markdown artifact per stage, and a human approval gate at every handoff. Packaged as a [Claude Code](https://claude.com/product/claude-code) plugin, this repository turns [Anthropic's AI-Native SDLC playbook](https://claude.com/blog/the-ai-native-sdlc-playbook) into something a team installs, not just something they read.

[![License: MIT](https://img.shields.io/badge/License-MIT-black.svg)](LICENSE)
![Claude Code plugin](https://img.shields.io/badge/Claude%20Code-plugin-black)
![Codex plugin](https://img.shields.io/badge/Codex-plugin-black)
![Stages](https://img.shields.io/badge/stages-6-black)

![The AI-native SDLC loop: Plan writes intent.md, Design writes spec.md, Build writes plan.md, Test produces tests and evals, Deploy runs REVIEW.md, Maintain watches bands.yaml, and a control-band breach files the next intent.md to restart the loop. A human gate separates every stage.](docs/loop.svg)

Agents generate, investigate, implement, and verify. Humans approve the decisions that need judgment. Git records who asked, what the agent produced, and who approved it.

> The name describes the method this implements — Anthropic's AI-Native SDLC playbook.
> This is an independent community implementation, not an Anthropic product, and is
> neither affiliated with nor endorsed by Anthropic.

---

## What is an AI-native SDLC?

An AI-native SDLC is a software development lifecycle designed around the fact that **code generation is no longer the bottleneck**. When an agent can implement a well-specified change in minutes, the constraint moves to the steps on either side of Build: deciding what to build, applying policy, verifying the result, reviewing it, authorizing release, and learning from production.

Traditional SDLC models move work between roles — analyst to designer to engineer to QA to ops. An AI-native SDLC replaces those role handoffs with an **artifact loop**. Each stage emits one version-controlled, human-readable, machine-executable Markdown file, committed beside the application code. The human does not write the artifact; the human **accepts** it. The repository becomes the audit trail.

This is sometimes called agentic SDLC, AI-driven SDLC, or spec-driven development. The distinguishing property here is not the Markdown — it is that **every handoff stops at a gate an agent cannot open by itself**.

## The six stages

| Stage | Skill that drives it | Purpose | Committed artifact | Human gate |
| --- | --- | --- | --- | --- |
| **1. Plan** | `sdlc-plan` | Capture the originator's problem, outcome, and constraints | `.sdlc/<slug>/intent.md` | Product owner accepts the intent |
| **2. Design** | `sdlc-design` | Turn accepted intent into requirements and a policy-aware design | `.sdlc/<slug>/spec.md` | Reviewer accepts scope and flagged concerns |
| **3. Build** | `sdlc-build` | Agree the implementation route before changing code | `.sdlc/<slug>/plan.md`, then code | Engineer accepts the plan |
| **4. Test** | `sdlc-test` | Produce deterministic evidence and regression-test the agent configuration | Test output, eval results, PR checks | Checks pass; owner assesses residual risk |
| **5. Deploy** | `sdlc-deploy` | Review consistently and stop at the production boundary | PR, review findings, release record | Code owner and release authority approve |
| **6. Maintain** | `sdlc-maintain` | Detect drift, diagnose it, feed learning back into Plan | Incident record or a new `intent.md` | Service owner triages the finding |

Stage 6 feeds Stage 1. That is the loop.

Two subagents serve it: `sdlc-reviewer` runs the `REVIEW.md` passes in Stage 5, and `sdlc-diagnostician` turns a control-band breach into a draft `intent.md` in Stage 6.

## Install

Works on **Claude Code** and **Codex**. Both read the same plugin directory — the six
stage skills, the hooks, and the artifact templates are shared; only the manifest and the
subagent format differ, and both are shipped.

A marketplace source can be a GitHub repo, a URL, or a local path, so a clone installs
the same way a published repo does.

### Claude Code

From the terminal — works everywhere, including surfaces where the `/plugin` dialog is
unavailable:

```bash
claude plugin marketplace add /absolute/path/to/ai-native-sdlc
```

```bash
claude plugin install ai-sdlc@ai-native-sdlc --scope user
```

From inside an interactive Claude Code session:

```text
/plugin marketplace add hieuvu7/ai-native-sdlc
/plugin install ai-sdlc@ai-native-sdlc
```

To try it for one session only, without installing anything:

```bash
claude --plugin-dir /absolute/path/to/ai-native-sdlc/plugins/ai-sdlc
```

`ai-sdlc` is the plugin; `ai-native-sdlc` is the marketplace it comes from. Installs are
stored under `~/.claude/plugins/`, shared by the CLI and the desktop app, so installing
once covers both. Pull in later edits with `claude plugin marketplace update ai-native-sdlc`.

### Codex

```bash
codex plugin marketplace add /absolute/path/to/ai-native-sdlc
```

```bash
codex plugin add ai-sdlc@ai-native-sdlc
```

Codex reads `plugins/ai-sdlc/.codex-plugin/plugin.json`, which points at the same
`skills/`, the same hook scripts through `hooks/hooks.codex.json`, and the `agents/*.toml`
subagent definitions. Nothing needs converting.

One difference matters. **Codex requires a one-time trust grant before plugin hooks run,
and only the interactive Codex TUI can give it.** Until you grant it there, the plugin's
skills and subagents work but the gates are advisory — the enforcement layer is off. Check
the plugin's hook state in the Codex TUI plugin menu after installing. Do not reach for
`--dangerously-bypass-hook-trust` to skip this; the trust prompt is the thing that makes a
hook safe to run.

Project memory also differs: Codex reads `AGENTS.md`, Claude Code reads `CLAUDE.md`.
`ai-sdlc-init` detects which the project uses and writes the same content to both when
both apply, from one template, so they cannot drift.

Read the next section before you install — this plugin registers hooks.

## What installing this changes on your machine

Read this before installing. This plugin ships hooks, and hooks run automatically.

Once the plugin is enabled, four hooks are registered for every session (immediately on
Claude Code; on Codex after you grant hook trust in its TUI):

| Hook | Fires | Does |
| --- | --- | --- |
| `artifact-gate.sh` | before every `Write` / `Edit` | Blocks a source-code write when the change has no accepted `plan.md` listing that file |
| `prod-guard.sh` | before every `Bash` | Blocks commands that look like a production deploy or teardown |
| `session-context.sh` | at session start | Prints the current stage and pending gate |
| `prompt-nudge.sh` | on every message you send | Prints one line naming the pending gate |

**Every one of them exits silently and immediately in a repository that has no `.sdlc/` directory.** That is the opt-in switch, and it is verified behavior, not an intention: installing this plugin does not change how Claude Code behaves in any repository where you have not run `/ai-sdlc-init`.

In a repository that has opted in, expect the gates to actually stop you. That is the point, and there are three escape hatches:

- `.sdlc/OPTOUT` — silences every hook for that repository, permanently, no other change needed.
- `AI_SDLC_ALLOW_PROD=1` — authorizes one production command after a human has approved it.
- `/plugin uninstall ai-sdlc` (Claude Code) or `codex plugin remove ai-sdlc@ai-native-sdlc` (Codex) — removes the hooks entirely.

Each block message names the rule that matched and the escape hatch, so a blocked action is never a mystery.

## Quickstart

From the repository you want to run the lifecycle in:

```text
/ai-sdlc-init
```

This scaffolds `.sdlc/`, writes a real `CLAUDE.md` for that project by inspecting its build, test, and lint commands, and copies the `REVIEW.md` and `bands.yaml` policy templates.

Then just describe the problem. No workflow keyword is needed; `sdlc-plan` picks it up:

```text
Customers keep calling support to ask where their claim is.
We should show them the status themselves.
```

The loop writes `.sdlc/<slug>/intent.md` and pauses for acceptance. After you accept, it writes `spec.md`, then `plan.md`, then implements and verifies the change — stopping at every gate. It never treats its own output as human approval.

Check where any change sits at any time:

```text
/ai-sdlc-status
```

## Stays on after install

Skill auto-triggering is probabilistic. Persistence here does not rely on it — four layers keep the lifecycle asserted, strongest first:

| Layer | Mechanism | Holds even if the model "forgets"? |
| --- | --- | --- |
| Enforcement | `PreToolUse` hooks block source writes with no accepted `plan.md`, and catch common production commands | Yes |
| Restoration | `SessionStart` re-injects the loop state at the start of every session | Yes |
| Nudge | `UserPromptSubmit` adds one line naming the current stage and pending gate | Yes |
| Memory | `/ai-sdlc-init` writes an idempotent block into the project's `CLAUDE.md` | Yes |

The ON switch is a single directory. `/ai-sdlc-init` creates `.sdlc/`, and that one act enables the lifecycle permanently for that repository. Every hook exits silently in repositories without it, so installing this plugin cannot change behavior in unrelated projects. `.sdlc/OPTOUT` is the OFF switch.

Stage state is **derived**, never stored — it is computed from which artifacts exist and what git says about them, so there is no state file to go stale.

## How it compares

| | This repository | [GitHub Spec Kit](https://github.com/github/spec-kit) | BMAD-METHOD | OpenSpec |
| --- | --- | --- | --- | --- |
| Covers Plan → Build | Yes | Yes | Yes | Yes |
| Covers Test, Deploy, Maintain | Yes | No | Partial | No |
| Human gate enforced by hooks | Yes | No | No | No |
| Production command guard | Best-effort | No | No | No |
| Control-band monitoring that files the next intent | Yes | No | No | No |
| Agent-configuration evals | Yes | No | No | No |
| Multi-agent tool support | Claude Code | 30+ agents | Model-agnostic | Model-agnostic |

Spec-driven development tools are mature for the front half of the lifecycle. This repository exists because the back half — verification, review policy, release authorization, and production feedback — is where the playbook's real claims live, and it is the part almost nothing implements.

## FAQ

### What does AI-native SDLC mean in practice?

Every stage produces one Markdown artifact that is committed to git and accepted by a named human before the next stage starts. `intent.md` → `spec.md` → `plan.md` → PR → production → band breach → the next `intent.md`.

### Does this let an AI agent deploy to production?

No. The `sdlc-deploy` skill is explicitly forbidden from merging or deploying, and Stage 6 proposes fixes through a pull request rather than applying one.

`prod-guard.sh` adds a second, weaker line: it catches the common shapes of deploy and teardown commands and requires explicit human authorization. Be clear about what that is worth — it is a speed bump, not a security boundary. A caller who spells a deploy differently will get past any regex. IAM permissions, deployment approvals, and branch protection remain the real controls, and this hook is not a reason to relax them.

### How is this different from spec-driven development?

Spec-driven development covers writing a spec and planning from it. This covers the full lifecycle including verification evidence, a review policy the agent must obey, release authorization, and monitoring that files the next intent when a service drifts.

### What are evals here, and why do they matter?

Evals are regression tests for the **agent configuration** rather than the code. When `CLAUDE.md`, a skill, or a hook changes, the eval suite re-runs — because a configuration change can silently degrade agent behavior with no failing unit test to show for it.

### Will installing this plugin affect my other repositories?

No. Every hook checks for a `.sdlc/` directory first and exits silently without one. This is verified behavior, not an intention.

### Does it work with Codex, or only Claude Code?

Both. The plugin ships a Claude Code manifest and a Codex manifest side by side, and the
skills, hook scripts, and templates are shared verbatim. The two differences are handled
for you: subagents ship in `.md` (Claude Code) and `.toml` (Codex), and project memory is
written to `CLAUDE.md` or `AGENTS.md` as the harness requires. The one thing you must do
yourself on Codex is grant hook trust in its TUI, without which the gates are advisory.

For any other agent, the methodology in [`docs/PLAYBOOK.md`](docs/PLAYBOOK.md) is
tool-neutral and the artifact templates are plain Markdown.

### Can I use my existing Jira or ServiceNow workflow?

Yes. Those can remain the system of record as long as commits link both ways. The artifacts are the decision trail, not a replacement tracker.

## Repository map

```text
.
├── README.md
├── docs/
│   ├── loop.svg          # The six-stage loop diagram
│   ├── PLAYBOOK.md       # Stage-by-stage operating model and artifact contract
│   ├── GOVERNANCE.md     # Enforceable controls and threat model
│   ├── METRICS.md        # Process health signals and how to compute them
│   └── ADOPTION.md       # Three-phase rollout
├── examples/rate-limit/  # One change walked through all six stages
├── plugins/ai-sdlc/
│   ├── .claude-plugin/   # Plugin manifest
│   ├── .codex-plugin/    # Codex plugin manifest
│   ├── skills/           # Six stage procedures plus ai-sdlc-init and ai-sdlc-status
│   ├── agents/           # sdlc-reviewer, sdlc-diagnostician (.md for Claude, .toml for Codex)
│   ├── hooks/            # Artifact gate, production guard, state, session context
│   └── templates/        # intent, spec, plan, CLAUDE, REVIEW, bands, settings
└── .claude-plugin/       # Marketplace catalog
```

## Documentation

- [**Playbook**](docs/PLAYBOOK.md) — the thesis, the loop, artifact templates, ownership, and gates.
- [**Governance**](docs/GOVERNANCE.md) — the controls that make policy executable, and the threat model behind them.
- [**Metrics**](docs/METRICS.md) — leading and lagging indicators, how to compute them, and how each gets gamed.
- [**Adoption**](docs/ADOPTION.md) — a rollout from one volunteer to the organization, and the failure modes on the way.

## What this is not

- Not permission for an agent to merge, approve, or deploy its own work.
- Not a replacement for product judgment, code ownership, incident command, or regulatory accountability.
- Not a new system of record forced on every team.
- Not a promise that Markdown makes weak requirements good — artifacts help only when reviewers reject ambiguity.
- Not a scorecard for ranking developers by agent usage, output, or speed.
- Not a reason to remove deterministic tests, static analysis, branch protection, sandboxing, or rollback practice.

Start with the artifacts, prove that the gates improve decisions, and automate only the paths the team can explain and audit.

## Credits

Method: [The AI-Native SDLC playbook](https://claude.com/blog/the-ai-native-sdlc-playbook), Anthropic Applied AI. This repository is an independent implementation and is not affiliated with or endorsed by Anthropic.

Licensed under the [MIT License](LICENSE).
