# Adoption

Adopt the workflow by increasing scope and control strength only after the prior phase produces understandable evidence.

The staged approach below applies the modular adoption principle from [Anthropic's AI-Native SDLC playbook](https://claude.com/blog/the-ai-native-sdlc-playbook) without requiring an organization-wide process change on day one.

The phases are cumulative:

1. One repository, one volunteer, artifacts only.
2. One team, hooks, `REVIEW.md`, and evals in CI.
3. Organization-wide managed settings and shared skills.

Do not skip directly to centralized enforcement.

Teams must first learn which artifacts improve decisions and which controls address real failures.

## Before starting

Choose a repository with active but bounded delivery work.

Avoid the most regulated, most critical, or least tested service as the first trial.

Name a product owner, an engineering owner, and one volunteer who wants to use the workflow.

Record the current baseline for intent-to-merge time, first-pass CI success, review time, rework, and change-failure rate.

Agree that the trial evaluates a process, not the volunteer's performance.

Keep existing branch protection, security scans, change management, and incident procedures in place.

## Phase 1: One repository, one volunteer, artifacts only

### Goal

Prove that a version-controlled artifact chain improves shared understanding before automating any gate.

The volunteer manually prompts every stage and stops for the named human decision.

No hook blocks work and no organization-wide setting changes.

### Entry criteria

- One repository has a stable build and test command.
- One volunteer has active work suitable for a two-to-four-week trial.
- A product owner can review intent and specification artifacts.
- An engineer can approve implementation plans and code changes.
- The team agrees on a `.sdlc/<slug>/` naming convention.
- Existing source-of-truth systems and required links are identified.
- The trial has a start date, review date, and rollback decision owner.

### What to turn on

Create the per-change artifact directory:

```text
.sdlc/<slug>/
├── intent.md
├── spec.md
└── plan.md
```

Use the templates and gates in [PLAYBOOK.md](PLAYBOOK.md).

Add a short root `CLAUDE.md` only if the repository lacks stable build, test, and convention instructions.

Prompt Plan, Design, and Build manually.

Record each human decision as a reviewed commit or pull-request decision.

Require the approved plan before implementation for trial changes.

Link each artifact to the existing ticket or change record.

Do not add automated status transitions.

Do not add a production agent.

### What to measure

- Time from source idea or ticket to committed `intent.md`.
- Time from accepted intent to approved `spec.md`.
- Time from approved plan to merged pull request.
- Specification changes after Build starts.
- Rework cycles per trial change.
- Whether reviewers can understand the change without the original chat.
- Artifact sections that reviewers repeatedly find empty, vague, or redundant.
- Volunteer and reviewer time spent maintaining artifacts.

Review a small sample of artifacts qualitatively every week.

The phase succeeds when reviewers use the artifacts to make earlier decisions and the team can point to at least one avoided misunderstanding or late rework cycle.

### What to do when stalled

If the volunteer cannot finish an intent, reduce the template to the problem, outcome, constraints, and open questions, then restore fields only when they serve a decision.

If reviews wait for days, set a small review service-level expectation and confirm the named owner has capacity.

If the spec duplicates a ticket, declare one source authoritative and link the other instead of maintaining two complete copies.

If plan approval happens after code begins, choose smaller work and make the plan a visible pull-request check before adding hooks.

If artifacts add no useful conversation after two weeks, inspect the actual documents; do not automate them.

Stop the trial if the team cannot name a decision improved by the chain.

Revise the artifact contract before resuming.

### Exit criteria

- At least three representative changes completed the artifact chain.
- Intent, specification, and plan approvals occurred before downstream work.
- Reviewers can locate the current decision and evidence from Git.
- Artifact maintenance cost is understood.
- The team has identified repeated violations worth enforcing.
- No open concern requires changing the fundamental workflow.

## Phase 2: One team, hooks, REVIEW.md, and evals in CI

### Goal

Make proven team rules repeatable and regression-test the configuration that guides agents.

Automation begins at boundaries the team already understands.

Humans still approve intent, specification, plan, merge, and production release.

### Entry criteria

- Phase 1 exit criteria are met.
- The team has enough trial evidence to identify one or two high-value deterministic gates.
- Required CI checks are stable and non-interactive.
- Branch protection already requires pull requests and independent review.
- The team can distinguish Important findings from nits.
- A platform or repository owner can maintain hooks and CI.
- There are 20 to 50 real agent tasks or incidents suitable for initial eval cases, or a documented plan to grow toward that range.

### What to turn on

Commit root `REVIEW.md` with three passes: bugs, security, and compliance against accepted artifacts.

Define Important, cap individual nits, and exclude generated or deterministically checked paths.

Add one fast hook for a demonstrated failure, such as protected-path edits or production commands without authorization.

Make every hook block explain the rule and approval route.

Add CI validation that `intent.md`, `spec.md`, and `plan.md` status transitions occur in order for scoped changes.

Create an eval suite from recent real tasks, repeated review findings, and incidents.

Run evals when any of these change:

```text
CLAUDE.md
REVIEW.md
bands.yaml
.claude/**
evals/**
```

Run evals on a schedule to expose model, dependency, and environment drift.

Make the eval threshold a required check only after the team understands variance and invalid cases.

Keep the agent identity unable to approve pull requests or bypass branch protection.

Begin non-interactive CI with read-only jobs such as failed-build triage or review.

Do not grant standing production credentials.

### What to measure

- Hook allow, ask, and block counts by rule.
- False-positive blocks and time lost to each gate.
- Time to first review and review finding precision from sampled ratings.
- First-pass CI success.
- Eval pass rate with case-set and configuration version.
- Production incident to permanent eval time.
- Regressions caught in CI versus production.
- Review comments resolved by the agent without human branch edits.
- Defects and vulnerabilities caught before merge versus escaped.
- Change-failure rate and failed-deployment recovery time.

Keep hook and eval data at team or repository level.

Do not publish individual agent-usage rankings.

### What to do when stalled

If hooks block legitimate work, narrow the matcher, add a safe allow path, and test the exact false-positive command before expanding coverage.

If users bypass hooks, investigate whether the control is too broad, too slow, or missing a legitimate exception route.

If `REVIEW.md` produces noise, rate findings weekly, sharpen Important, lower the nit cap, and remove checks already handled by CI.

If evals are flaky, freeze fixtures, record model and tool versions, separate infrastructure errors, and replace model graders with deterministic checks where possible.

If the eval pass rate is always perfect, add real failures and harder boundary cases instead of celebrating saturation.

If CI cost is high, run a small required smoke set on pull requests and the full suite nightly.

If review latency rises, reduce generated diff size and work in smaller independently reviewable changes before adding more agent concurrency.

If the team clicks every approval immediately, pause automation and audit a sample of approvals against artifact quality.

### Exit criteria

- Hook false positives are low and reviewed on a stable cadence.
- `REVIEW.md` findings are rated useful by code owners.
- Evals fail on known-bad configurations and pass on the approved baseline.
- CI jobs have bounded tools, identity, budget, timeout, and structured output.
- Branch protection preserves independent approval.
- Incidents are linked to corrective tests or evals.
- The team can explain every automated gate and its evidence.

## Phase 3: Organization-wide managed settings and shared skills

### Goal

Scale stable controls and institutional knowledge across repositories without allowing local configuration to weaken non-negotiable boundaries.

Teams retain room to add stricter repository rules and domain-specific skills.

The organization controls the minimum floor.

### Entry criteria

- At least one team meets Phase 2 exit criteria over multiple delivery cycles.
- Security, platform, compliance, and developer-experience owners agree on the threat model.
- Every shared policy and skill has a named owner and source of truth.
- An approved plugin or distribution channel exists.
- The organization can deploy managed settings in rings and roll them back.
- Support, exception, and break-glass processes are documented.
- Audit log retention, privacy, and access rules are approved.
- Pilot metrics show the controls improve process health without unacceptable friction.

### What to turn on

Publish shared skills for policies that must be applied consistently across repositories.

Keep service-specific commands and architecture in local `CLAUDE.md` files.

Use managed settings to enforce the organization-wide minimum:

- Permission bypass is disabled.
- Non-negotiable hooks come only from managed configuration.
- MCP servers and plugin marketplaces are allowlisted.
- Sandboxing fails closed where required by data classification.
- Network egress and credential exposure are restricted.
- A minimum supported client version is enforced.
- Production agents have no standing credentials.

Distribute settings in rings: platform test, volunteer teams, representative business units, then broad deployment.

Publish an effective-policy inspection command so teams can see which rule applies and why.

Protect shared skills, managed configuration, eval fixtures, and hook code with policy-owner review.

Run a shared core eval suite plus repository-specific suites.

Provide approved non-interactive CI patterns for read-only triage, review, patch proposal, and deployment preparation.

Keep production release authorization with the existing accountable human role.

### What to measure

- Repositories and active teams on the approved managed baseline.
- Time from a policy-owner decision to the shared skill release reaching teams.
- Review findings that cite policy already encoded in a skill.
- Managed-setting denials and false positives by policy version.
- Hook bypass attempts and approved exceptions.
- Sandbox startup failures and blocked egress destinations.
- Shared and local eval pass rates by configuration version.
- Time to first merged pull request for a new team member.
- DORA measures by service class.
- Gate violations reaching production.
- Repeat incidents of classes covered by shared controls.
- Support volume and median exception resolution time.

Use cohort and service-level trends.

Never interpret adoption percentage as proof of value by itself.

### What to do when stalled

If teams reject shared skills, compare them with the current policy source and remove generic instructions that do not produce a concrete action.

If managed settings break local builds, pause the rollout ring, reproduce the denial, and add the smallest reviewed capability rather than a global bypass.

If exception volume grows, group requests by root cause and decide whether the control, documentation, toolchain, or service architecture needs change.

If policy rollout is slow, version the shared plugin, publish compatibility notes, and automate safe distribution instead of asking each team to copy files.

If teams fork skills locally, identify the missing extension point; keep the mandatory core central and permit explicit local overlays.

If dashboards become competitive league tables, remove individual and cross-team rankings and return to service baselines and outcome review.

If a centralized control causes an incident, roll back the policy ring, preserve the evidence, add an eval, and treat the control like production code.

### Exit criteria

Phase 3 is an operating state, not a one-time completion event.

The organization is healthy when:

- The minimum controls are centrally enforced and locally inspectable.
- Shared skills remain traceable to owned policy.
- Teams can request and receive bounded exceptions.
- Configuration changes run through evals and staged rollout.
- Production authority remains separated from generation authority.
- Metrics show lower rework or risk without hidden developer friction.
- Incidents improve the shared system rather than only the affected repository.

## Common failure modes

### Cargo-cult artifacts

The symptom is a complete directory of polished Markdown that nobody uses to decide anything.

Templates are filled because the workflow asks for them, not because a downstream reader needs the content.

Agents repeat the same prose across intent, specification, and plan.

Reviewers approve formatting rather than substance.

Corrective action:

- Ask who consumes each section and what decision it changes.
- Delete or combine sections with no consumer.
- Sample artifacts against the final diff and production outcome.
- Reject generic content such as "follow best practices" or "add tests."
- Prefer a short disputed artifact to a long ceremonial one.
- Do not automate creation until manual artifacts repeatedly help.

### Gates everyone clicks through

The symptom is near-zero approval time, no rejected transitions, and defects that the declared gate should have caught.

The gate exists in UI or status but has no decision standard.

Corrective action:

- State the condition the approver must evaluate.
- Show the exact evidence beside the approval request.
- Bind approval to the reviewed commit SHA.
- Sample approved changes and discuss misses without blaming individuals.
- Remove low-value approval prompts that create fatigue.
- Automate deterministic conditions and reserve asks for real judgment.
- Preserve independent code-owner and release authority.

### `spec.md` written after code

The symptom is a specification commit at or after the implementation commit, with language that perfectly describes the existing diff.

The artifact has become retroactive documentation, not a Design gate.

Corrective action:

- Check artifact order from Git timestamps in CI.
- Require approved `spec.md` before approved `plan.md` and source changes.
- For an emergency path, record the exception explicitly and run retrospective Design review after recovery.
- Do not falsify dates or squash away the sequence.
- If work routinely starts before a spec, reduce change size and shorten the review service level.
- Treat late discovery as a visible revision, not a reason to write history backward.

### Too much automation too early

The symptom is a web of triggers, hooks, and agent jobs whose owners cannot explain why they run.

Corrective action:

- Return transitions to manual prompts.
- Keep only controls tied to observed failures.
- Rebuild automation one boundary at a time with evidence and rollback.

### Advisory policy mistaken for enforcement

The symptom is a skill that says "never" while no deterministic control detects or blocks the forbidden action.

Corrective action:

- Classify the rule by consequence.
- Back non-negotiable rules with hooks, branch rules, sandbox policy, or CI.
- Keep the skill as just-in-time explanation and procedure.

### Central rollout mistaken for adoption

The symptom is high installation coverage with low artifact quality, ignored findings, frequent exceptions, or rising review fatigue.

Corrective action:

- Measure outcomes and friction, not installation count alone.
- Conduct artifact and control reviews with representative teams.
- Let evidence from local use reshape the shared baseline.

## Rollback policy

Every phase needs a rollback that preserves the audit trail.

Phase 1 rollback stops requiring new artifacts but keeps completed `.sdlc/` history.

Phase 2 rollback disables the failing required check or hook through a reviewed change, never through an undocumented local bypass.

Phase 3 rollback removes the affected managed-policy version from the current deployment ring and restores the last known-good version.

After rollback, record the trigger, impact, decision owner, restored version, and eval that would catch recurrence.

Adoption is successful when the process becomes easier to trust, not merely harder to bypass.
