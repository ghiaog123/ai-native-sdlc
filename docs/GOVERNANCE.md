# Governance as Code

Governance is effective when the control runs at the point of action, produces evidence, and cannot be silently waived by the actor it governs.

This document translates the control model in [Anthropic's AI-Native SDLC playbook](https://claude.com/blog/the-ai-native-sdlc-playbook) into enforceable repository and platform mechanisms.

The examples are starting points.

Review every command, path, identity, and domain against the target repository's threat model before enabling it.

## Control principles

1. Advisory controls make safe behavior likely; deterministic controls make forbidden behavior fail.
2. The identity that generates a change cannot approve the same change.
3. An agent receives the least authority needed for the current stage and environment.
4. Production authorization is bound to a person, commit, environment, and time window.
5. The control and its evidence are versioned or centrally logged.
6. A failed control fails closed when the protected consequence is material.
7. Every block explains the reason and the route to a valid approval.
8. Controls are tested, observed, and removed when they no longer address a real threat.

## Control stack

| Layer | Mechanism | Nature | Primary evidence |
| --- | --- | --- | --- |
| Guidance | Skills | Advisory | Skill version and invocation trace |
| Action | Hooks | Deterministic at tool boundary | Hook input, verdict, reason, timestamp |
| Administration | Managed settings | Centrally enforced | Admin policy and client posture |
| Change | Branch protection | Deterministic at merge boundary | PR checks, reviews, merge event |
| Execution | Sandboxing | OS and network isolation | Sandbox policy and execution log |
| History | Git audit trail | Tamper-evident collaboration record | Commits, signatures, reviews, tags |
| Behavior | Evals | Regression gate for agent configuration | Task results, graders, pass threshold |
| Automation | Non-interactive CI | Reproducible bounded execution | Job identity, inputs, tools, outputs |

No single layer is sufficient.

A skill can be ignored.

A hook cannot protect a direct push made outside the agent.

Branch protection cannot stop a CI job from reading a secret it never needed.

Sandboxing cannot decide whether a product requirement is ethical or useful.

The stack composes these controls around different failure surfaces.

## Skills

### What skills stop

Skills reduce inconsistent application of institutional knowledge while an agent plans, designs, builds, or reviews.

They stop teams from repeatedly pasting stale policy fragments into prompts.

They make the applicable security, brand, accessibility, architecture, and compliance procedure discoverable at the moment it matters.

They do not stop a determined bypass and must not be the only control behind a non-negotiable rule.

### What skills cost

Skills consume context and require a named policy owner.

Over-broad trigger descriptions load irrelevant guidance and make results worse.

Policy changes require skill updates, review, rollout, and regression evaluation.

A skill that restates a large policy manual without an executable procedure creates maintenance work without improving decisions.

### Worked example

Place a repository skill at `.claude/skills/external-api/SKILL.md`:

```markdown
---
name: external-api
description: Apply when creating or changing a public HTTP endpoint or OpenAPI contract.
---

# External API control

Before proposing or editing an external endpoint:

1. Read `policy/api-security.md` at the current commit.
2. Require authentication except for the documented health endpoint.
3. Validate request bodies against the published schema and reject unknown fields.
4. Keep fields classified as restricted out of logs, errors, and traces.
5. Add an integration test for authorization and invalid input.
6. Run `./scripts/check-public-api.sh` and attach its output.

If requirements conflict with the policy, stop and name the conflict in `spec.md`.
The security owner must resolve the conflict; do not choose an exception.
```

The policy owner is a code owner for that directory.

An eval checks that paraphrased endpoint tasks still trigger the skill and satisfy its deterministic checks.

## Hooks

### What hooks stop

Hooks stop unsafe tool calls at the action boundary.

Typical uses are protected-path edits, accidental credential inclusion, destructive commands, edits to tests during a constrained bug fix, and production deployment without authorization.

Hooks convert a policy from a reminder into an allow, ask, or block decision.

### What hooks cost

Every matching action pays hook latency.

Broad matchers generate prompt fatigue and encourage users to seek bypasses.

Shell parsing is easy to get wrong; commands can be expressed in unexpected forms.

Hooks need unit tests, structured logs, ownership, and a recovery path when the hook service is unavailable.

Keep fast checks at tool use and move full scans to commit or pull-request time.

### Worked example: real hook configuration

Commit the following as `.claude/settings.json` for a team-level production command gate:

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          {
            "type": "command",
            "command": "${CLAUDE_PROJECT_DIR}/.claude/hooks/production-gate.sh",
            "timeout": 5
          }
        ]
      }
    ]
  }
}
```

The hook receives the tool request on standard input and returns a blocking exit status when authorization is missing:

```bash
#!/usr/bin/env bash
set -euo pipefail

payload="$(</dev/stdin)"
command="$(jq -r '.tool_input.command // ""' <<<"$payload")"

if [[ "$command" != *"deploy"* || "$command" != *"production"* ]]; then
  exit 0
fi

if [[ -z "${RELEASE_APPROVAL_ID:-}" || -z "${APPROVED_SHA:-}" ]]; then
  echo "Blocked: production requires a release approval ID and approved commit SHA." >&2
  exit 2
fi

current_sha="$(git rev-parse HEAD)"
if [[ "$current_sha" != "$APPROVED_SHA" ]]; then
  echo "Blocked: HEAD does not match the commit authorized for release." >&2
  exit 2
fi

exit 0
```

The approval lookup should validate issuer, environment, expiry, and commit rather than trusting freely set local environment variables.

Use an external signed approval record or CI environment approval for production.

## Managed settings

### What managed settings stop

Managed settings stop local project files, user preferences, or command-line flags from widening centrally required controls.

They can deny sensitive paths, disable permission bypass, require sandboxing, restrict network destinations, permit only managed hooks and MCP servers, disable sideloaded plugins, and enforce a minimum client version.

They are the appropriate layer for requirements that must apply across every repository and workstation in scope.

### What managed settings cost

Central policy reduces local flexibility and can break legitimate workflows.

Platform teams inherit support load, staged rollout responsibility, exception handling, and client compatibility testing.

An allowlist that is too small blocks work; one that grows without review becomes an unexamined permit list.

Managed policy changes need change control because one mistake can affect the whole organization.

### Worked example

The following managed-settings fragment fails closed when the sandbox is unavailable and prevents local widening:

```json
{
  "permissions": {
    "deny": [
      "Read(.env*)",
      "Read(./secrets/**)",
      "Bash(curl *)",
      "Bash(wget *)"
    ],
    "allow": [
      "Bash(git status*)",
      "Bash(make build)",
      "Bash(make test)",
      "Bash(make lint)"
    ],
    "disableBypassPermissionsMode": "disable"
  },
  "allowManagedPermissionRulesOnly": true,
  "allowManagedHooksOnly": true,
  "allowManagedMcpServersOnly": true,
  "disableSideloadFlags": true,
  "sandbox": {
    "enabled": true,
    "failIfUnavailable": true,
    "allowUnsandboxedCommands": false,
    "network": {
      "allowedDomains": [
        "git.example.internal",
        "registry.npmjs.org"
      ]
    }
  }
}
```

Deploy to a pilot group first.

Record denied actions and review false positives before expanding the policy.

## Branch protection

### What branch protection stops

Branch protection stops an agent, CI identity, or human from bypassing review by pushing directly to the protected branch.

It requires a pull request, current checks, resolved conversations, code-owner review, and a fresh approval after the last push.

It preserves separation of duties after the agent has written or amended code.

### What branch protection costs

Required checks add queue and execution time.

Code-owner rules can concentrate approvals on too few people.

Stale-review dismissal causes re-review after every change, including mechanical fixes.

Emergency changes need a documented, audited break-glass route rather than an invisible bypass actor.

### Worked example: real GitHub repository ruleset

Apply this object through `POST /repos/{owner}/{repo}/rulesets`, adjusting check names to match the repository:

```json
{
  "name": "protect-default-branch",
  "target": "branch",
  "enforcement": "active",
  "bypass_actors": [],
  "conditions": {
    "ref_name": {
      "include": ["~DEFAULT_BRANCH"],
      "exclude": []
    }
  },
  "rules": [
    { "type": "deletion" },
    { "type": "non_fast_forward" },
    {
      "type": "required_status_checks",
      "parameters": {
        "strict_required_status_checks_policy": true,
        "do_not_enforce_on_create": false,
        "required_status_checks": [
          { "context": "ci/test" },
          { "context": "agent-evals" },
          { "context": "review-policy" }
        ]
      }
    },
    {
      "type": "pull_request",
      "parameters": {
        "allowed_merge_methods": ["squash", "merge"],
        "required_approving_review_count": 1,
        "dismiss_stale_reviews_on_push": true,
        "require_code_owner_review": true,
        "require_last_push_approval": true,
        "required_review_thread_resolution": true
      }
    }
  ]
}
```

Give the agent identity `contents: write` only on feature branches and no ruleset bypass role.

Protect changes to `CLAUDE.md`, `REVIEW.md`, `bands.yaml`, skills, hooks, workflows, and CODEOWNERS with appropriate owners.

## Sandboxing

### What sandboxing stops

Sandboxing limits the blast radius when an allowed tool or generated command behaves unexpectedly.

It prevents arbitrary filesystem reads, unrestricted network egress, access to long-lived credentials, privileged processes, and writes outside the workspace.

It closes gaps that tool-name permission rules cannot see inside a shell process.

### What sandboxing costs

Isolation adds startup time and makes some builds harder.

Network allowlists require dependency inventory and proxy support.

Containerized or remote runners need caches, test fixtures, and local-service substitutes.

Debugging a denial requires observable policy decisions without leaking protected data.

### Worked example

Run a non-interactive agent job in an ephemeral container with these properties:

```yaml
securityContext:
  runAsNonRoot: true
  readOnlyRootFilesystem: true
  allowPrivilegeEscalation: false
  capabilities:
    drop: ["ALL"]
resources:
  limits:
    cpu: "2"
    memory: "4Gi"
volumeMounts:
  - name: workspace
    mountPath: /workspace
  - name: tmp
    mountPath: /tmp
env:
  - name: HOME
    value: /tmp/agent-home
```

Mount the repository workspace read-write, mount no home-directory credentials, issue a short-lived token for the specific repository, and enforce network egress outside the pod specification.

Production credentials are never injected into an implementation or review job.

## Git audit trail

### What the Git trail stops

Git prevents undocumented artifact replacement from becoming the accepted history.

It records who proposed intent, which specification and plan were approved, how implementation departed, which review findings were fixed, and which commit reached production.

Signed commits and protected tags make identity and release provenance stronger.

Git does not prove that the human understood the artifact, so it must be paired with meaningful review.

### What the Git trail costs

Artifacts create review surface and repository history.

Teams must keep secrets, sensitive incident data, and personal information out of commits.

Amending or squashing can erase intermediate evidence if the retention policy is not explicit.

External systems need bidirectional links when Git is not the formal record.

### Worked example

Use commit trailers to make approvals and relationships machine-queryable:

```text
sdlc(design): approve customer-claim-status specification

Artifact: .sdlc/customer-claim-status/spec.md
Derived-From: 4d3c2b1
Status: Approved
Approved-By: product-owner@example.com
Policy-Owners: security@example.com,privacy@example.com
Record: JIRA-1842
```

The release record stores the exact merge SHA and deployment environment.

Do not use a mutable branch name as release provenance.

## Evals

### What evals stop

Evals stop changes to agent configuration from silently degrading future behavior.

They cover `CLAUDE.md`, skills, hooks, prompts, models, tool permissions, and orchestration.

They convert production incidents and recurring review failures into permanent regression cases.

Deterministic graders should be preferred where behavior can be checked by code.

### What evals cost

Model runs consume time and money and may have residual variance.

Fixtures drift as the codebase changes.

Easy cases saturate and create a misleadingly high pass rate.

Rubric graders require calibration and disagreement review.

The suite needs ownership like any other production test suite.

### Worked example: real eval trigger

This GitHub Actions workflow runs on every agent-configuration pull request, nightly, and by manual dispatch:

```yaml
name: Agent evals

on:
  pull_request:
    paths:
      - "CLAUDE.md"
      - "REVIEW.md"
      - "bands.yaml"
      - ".claude/**"
      - "evals/**"
  schedule:
    - cron: "17 2 * * *"
  workflow_dispatch:

permissions:
  contents: read

jobs:
  evaluate:
    runs-on: ubuntu-latest
    timeout-minutes: 30
    steps:
      - uses: actions/checkout@v4
      - name: Run bounded eval suite
        env:
          ANTHROPIC_API_KEY: ${{ secrets.EVALS_ANTHROPIC_API_KEY }}
        run: ./evals/run.sh --non-interactive --threshold 0.90
```

The runner writes one result per case, records model and configuration versions, and fails the required check below the approved threshold.

Add a case after every material production incident before closing its corrective action.

## Non-interactive CI

### What non-interactive CI stops

Non-interactive CI stops automation from depending on an unrecorded local conversation or an engineer clicking through tool prompts.

It makes inputs, identity, allowed tools, budget, timeout, and outputs reproducible.

It is suitable for bounded work such as build-failure triage, changelog drafting, review, eval execution, and proposing a fix through a pull request.

It is not a reason to give the runner production credentials.

### What non-interactive CI costs

Jobs consume model budget and runner capacity.

Logs can expose sensitive prompts or output if retention and redaction are weak.

Retries can multiply cost or duplicate external actions.

Long-running work needs timeouts, idempotency, cancellation, and a clear partial-output policy.

### Worked example

Use a read-only first step for failed-build triage:

```yaml
- name: Triage failed build
  if: failure()
  timeout-minutes: 5
  env:
    ANTHROPIC_API_KEY: ${{ secrets.TRIAGE_ANTHROPIC_API_KEY }}
  run: |
    claude -p "Read out/build.log. Classify the failure as deterministic, flaky, or unknown. Cite the relevant lines and write a three-line PR summary. Do not edit files." \
      --allowedTools "Read" \
      --output-format json \
      > out/triage.json
```

Give the job a dedicated identity, read-only checkout, no production credentials, a hard timeout, and an output schema check.

When write authority is later added, restrict it to a feature branch and require the protected pull-request path.

## Persistence: How the Loop Stays Active

Installing a workflow is not enough. The loop must survive new sessions, context resets, and ordinary task switching. Four layers provide that persistence, ordered from strongest to weakest:

1. **`PreToolUse` hooks provide enforcement.** `artifact-gate.sh` blocks code writes when the active change has no `plan.md` listing the file. `prod-guard.sh` catches the common shapes of production commands. They run at the tool boundary and add no per-message prompt cost.

   These two are not equally strong, and conflating them is dangerous. The artifact gate is a real boundary: it reasons about repository state the agent cannot fake, so it either holds or fails closed. The production guard is pattern matching over a command string, which means it is defense in depth and nothing more — it raises the cost of an unreviewed deploy and creates an audit signal, but a determined or merely creative caller gets past it. Never let its presence justify loosening IAM scopes, deployment approvals, or branch protection, which are the controls that actually enforce this boundary. Measure it by how often it catches an honest mistake, not by whether it could stop an adversary.
2. **The `SessionStart` hook restores the operating state.** At the start of each session it re-injects a concise loop briefing with the applicable stage skills and pending gates. It exists because a fresh context cannot be assumed to remember the active stage. Like the tool gates, it is automatic and has no per-message cost.
3. **The `UserPromptSubmit` hook supplies the nudge.** While work is in flight, it adds one line naming the current stage and gate on each turn; when nothing is in flight, it is silent. This is the only layer paid on every message, so the trade-off is explicit: keep the line minimal and silent by default.
4. **The `CLAUDE.md` block provides durable memory.** Initialization appends the block, and Claude loads it independently in every session. It preserves the repository's loop contract even when hook context is unavailable, at the cost of a small amount of persistent session context.

The first layer enforces; the middle layers restore and nudge; the last remembers. Together they keep safety-critical checks deterministic while using the smallest practical amount of recurring context.

The predictable failure mode is well-intentioned cleanup: a team disables noisy hooks believing it is improving the experience, and the loop quietly dies. Keep nudges minimal, make every gate actionable, and provide `.sdlc/OPTOUT` as a legitimate escape hatch so teams opt out honestly instead of dismantling controls piecemeal.

## Threat model

| Failure | Primary control | Supporting controls | Evidence |
| --- | --- | --- | --- |
| Agent ignores an organizational standard | Skill | Eval, review pass, policy owner | Skill version, eval result, PR finding |
| Agent edits a protected or generated path | Hook | Managed settings, review | Hook block and attempted path |
| Agent reads local secrets | Sandbox | Managed deny rules, short-lived credentials | Sandbox denial and job identity |
| Agent exfiltrates data through shell networking | Sandbox egress policy | Managed settings, proxy logs | Denied destination and process log |
| User disables a non-negotiable hook | Managed settings | Admin posture checks | Effective managed policy |
| Agent pushes directly to main | Branch protection | Scoped token, no bypass actor | Rejected ref update |
| Agent approves its own change | Branch protection | Distinct identities, CODEOWNERS | Required independent review |
| Agent deploys an unreviewed commit | Production hook | Release environment approval, SHA binding | Approval ID and deployed SHA |
| Agent weakens a test to make a fix pass | Test-path hook | PR review, failing-test-first workflow | Blocked edit or explicit review |
| Prompt or skill change regresses behavior | Evals | Required check, scheduled run | Versioned case results |
| CI agent runs forever or spends without bound | Non-interactive CI limits | Budget alerts, cancellation | Timeout and usage log |
| CI retries duplicate an external action | Idempotent job design | Unique operation key, audit API | Operation key and provider response |
| Artifact is written after implementation | Git artifact order check | Branch rule, review policy | Commit timestamps and failed check |
| Review becomes a rubber stamp | CODEOWNERS and review policy | Review-quality sampling, incident feedback | Findings, approval latency, escapes |
| Production drift is diagnosed probabilistically without a real breach | Deterministic `bands.yaml` detector | Versioned baseline, unit tests | Metric, rule, threshold, breach time |
| Incident learning disappears after closure | Eval and new intent requirement | Post-incident checklist, Git trail | Linked incident, eval, and corrective PR |

## Control review cadence

Review hook blocks and sandbox denials weekly during rollout, then monthly when stable.

Review skill ownership and source-policy versions whenever the upstream policy changes.

Review branch bypass actors and CI token scopes quarterly.

Review eval discrimination, flaky cases, cost, and production coverage monthly.

Exercise rollback and production authorization in staging on a schedule.

Remove controls that no longer map to a threat, but preserve the decision record explaining why.

Governance as code is not governance without judgment.

The code makes boundaries repeatable; accountable people choose the boundaries and own the exceptions.
