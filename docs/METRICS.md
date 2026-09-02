# Metrics

The metrics in this document operationalize the leading and lagging indicators named in [Anthropic's AI-Native SDLC playbook](https://claude.com/blog/the-ai-native-sdlc-playbook).

> These are health signals for the delivery process, not developer performance scores. Do not rank, compensate, promote, discipline, or compare individuals with them. Individual scorekeeping will corrupt the data and damage the review behavior the system depends on.

## How to read the signals

A leading indicator shows whether the loop is becoming faster, more automated, or more consistent before production outcomes are known.

A lagging indicator shows whether the change survived review and production with the intended result.

Neither kind is sufficient alone.

Faster intent capture can create more low-quality intents.

Higher first-pass CI success can mean better local feedback or weaker tests.

More merged changes can mean better flow or smaller, trivial work.

Read speed with quality, automation with escapes, and throughput with rework.

Compare a team or service with its own baseline and work mix.

Use medians and percentiles for elapsed times; averages hide long queues.

Segment high-risk, routine, incident, dependency, and documentation changes before drawing conclusions.

## Required event model

Metrics are reliable only when artifacts share a stable change key.

Use the `.sdlc/<slug>/` slug in commits, pull requests, CI metadata, deployment records, incidents, and eval cases.

At minimum, collect these events:

| Event | Required fields | Source |
| --- | --- | --- |
| Intent created | slug, first-source time, first-commit time, author | Ticket/chat connector and Git |
| Intent decided | slug, status, decision time, product owner | Git review or artifact commit |
| Spec approved | slug, commit SHA, approval time, approver | Git and pull request |
| Plan approved | slug, commit SHA, approval time, approver | Git and pull request |
| PR opened | slug, PR number, head SHA, opened time | Git provider |
| Review event | PR, reviewer type, finding, severity, time | Git provider check or review |
| Check run | PR, SHA, check name, attempt, conclusion, times | CI |
| Merge | PR, merge SHA, merge time | Git provider |
| Deployment | merge SHA, environment, start, finish, result | CD platform |
| Incident | service, deploy SHA, class, start, recovery, severity | Incident system |
| Band breach | metric, rule, tier, breach time, value | Detector log |
| Eval run | config SHA, case version, model, result, duration | CI |

Preserve raw events.

Derived dashboards change; evidence should not.

## Plan indicators

| Indicator | Precise definition | Compute from Git or workflow data | What good looks like | How it gets gamed |
| --- | --- | --- | --- | --- |
| Intent capture time | Hours from the earliest recorded source event for a slug to the first commit adding `.sdlc/<slug>/intent.md` | Join ticket or conversation timestamp to `git log --diff-filter=A --format=%cI -- .sdlc/<slug>/intent.md`; report median and p90 | Falls from the team's baseline without lower acceptance or more late intent edits | Starting the timer late, pre-writing offline, or committing empty templates |
| Intent survival rate | Accepted intents divided by all intents with a terminal `Accepted` or `Rejected` decision in the period | Parse final status at the decision commit; `accepted / (accepted + rejected)` | Stable enough to show capture is useful; no universal maximum because healthy discovery rejects weak ideas | Accepting everything, never closing weak intents, or deleting rejected artifacts |
| Post-spec intent edits | Count of commits changing `intent.md` after the first commit adding `spec.md`, per slug | Compare `git log --format=%ct` for both paths; exclude metadata-only automated changes by a declared rule | Low and explainable; material edits represent discovery and restart downstream review | Hiding changed intent in tickets, editing only the spec, or squashing timestamps |

Interpret the three together.

Short capture time with falling survival may mean premature artifacts.

High survival with many post-spec edits may mean approval is ceremonial.

## Design indicators

| Indicator | Precise definition | Compute from Git or workflow data | What good looks like | How it gets gamed |
| --- | --- | --- | --- | --- |
| Intent-to-spec elapsed time | Hours from the commit that accepts `intent.md` to the commit that first sets `spec.md` to `Approved` | Read status-transition commits for the two paths and subtract committer timestamps; report median and p90 | Decreases while requirements rework and production escapes stay flat or improve | Marking a thin spec approved, resolving policy outside the artifact, or changing timestamps through squash |
| Requirements rework after build starts | Material `spec.md` commits after the first approved `plan.md`, divided by changes that entered Build | Use `git log --name-status`; classify material versus metadata edits with reviewed labels | Trends down; remaining rework is explicitly classified as discovery, miss, or external change | Calling requirement changes "implementation details" or editing code without updating the spec |

Do not set a target of zero requirements rework.

Zero can mean no learning is recorded.

Review a sample of classifications each month.

## Repository memory and shared-skill indicators

| Indicator | Precise definition | Compute from Git or workflow data | What good looks like | How it gets gamed |
| --- | --- | --- | --- | --- |
| Repeated mistakes `CLAUDE.md` should have caught | Confirmed review findings or corrections that match an active root `CLAUDE.md` rule and occurred after that rule merged | Tag findings with rule IDs; join finding time to `CLAUDE.md` rule introduction commit; deduplicate one root cause per PR | Falls toward zero; recurrence triggers instruction clarity, loading, or enforcement review | Giving rules vague IDs, not tagging findings, or moving important rules out of the measured file |
| Time to first merged PR for a new team member | Elapsed days from team start date to that person's first merged, non-trivial pull request | Join roster start date to first qualifying merge in PR history; publish only cohort aggregates | Falls while onboarding quality, review findings, and early change-failure rate remain sound | Assigning trivial PRs, backdating start, or using it to pressure individuals |
| Policy approval to skill merge time | Hours from the policy owner's recorded approval of a policy change to merge of the corresponding shared-skill update | Link policy record ID in the skill PR; subtract approval event from `mergedAt` | Predictable and shorter than the old policy-distribution path without bypassing owner review | Recording approval late, pre-merging before approval, or omitting slow changes |
| Review findings citing encoded policy | Confirmed PR findings citing a policy that an active skill should have applied, per 100 relevant PRs | Tag skill and policy IDs in review findings; divide by PRs where the skill trigger should match | Falls toward zero; persistence identifies trigger failure or drift from the source policy | Avoiding policy tags, narrowing trigger eligibility, or suppressing valid findings |

These signals measure whether institutional knowledge reaches work, not how obedient an individual appears.

## Build indicators

| Indicator | Precise definition | Compute from Git or workflow data | What good looks like | How it gets gamed |
| --- | --- | --- | --- | --- |
| First-pass implementation merge share | Merged change PRs that required no material implementation revision after the first complete agent push, divided by merged change PRs | Mark the first complete push in PR metadata; classify later commits excluding merge-base updates and mechanical formatting | Rises alongside stable review finding severity and change-failure rate | Declaring completion late, packing corrections into the first push, or labeling material fixes mechanical |
| Plan approval to merged PR | Hours from approved `plan.md` commit to merge time for the linked PR | Join slug and plan approval SHA to PR `mergedAt`; report median, p75, and p90 | Falls without rising rework, review load, or escapes | Approving the plan only after implementation, opening replacement PRs, or excluding stalled work |
| Rework cycles per change | Number of material author-update cycles after review or failed checks and before merge | Group review-request, check-failure, and subsequent push events; collapse pushes within a defined 15-minute batch | Low and declining for comparable change classes | Combining many fixes into one cycle or avoiding review comments through private messages |
| Plan/diff match rate | Merged changes whose touched files and material behavior remain within approved `plan.md`, or have approved deviations, divided by merged changes | Compare PR file list with `Files that change`; require entries in `Deviations` for out-of-plan files | High, with visible approved deviations rather than artificial perfection | Writing vague file globs, updating the plan after code without review, or ignoring behavior mismatch |
| Concurrent sessions per engineer while review quality holds | Median simultaneously active agent sessions during steering windows, segmented by stable review and escape rates | Use session telemetry start/finish plus PR review and incident data; aggregate only at team level | Increases only until review latency or quality begins to degrade | Leaving idle sessions open, counting subagents as full streams, or suppressing findings |
| Share of day spent steering rather than waiting | Team-level active steering minutes divided by steering plus tool-wait minutes during sampled work | Use privacy-reviewed session telemetry with a published classification; aggregate by team and month | Waiting declines while sustainable workload and review quality hold | Simulating activity, redefining waiting, or using it to monitor individuals |
| Changes merged per engineer per week, read with rework | Merged change PRs divided by active team members and weeks, always paired with rework and change mix | Count merges by team ownership, not PR author identity; normalize by staffed weeks | Throughput rises without higher rework or failure rate | Splitting trivial PRs, avoiding hard work, attributing agent PRs strategically, or pressuring individuals |

The last three are especially unsafe as individual metrics.

Publish only sufficiently aggregated views and suppress small cohorts.

## Test indicators

| Indicator | Precise definition | Compute from Git or workflow data | What good looks like | How it gets gamed |
| --- | --- | --- | --- | --- |
| First-pass CI success rate | PRs whose first complete required-check suite passed without rerun or code change, divided by PRs that started required checks | Use check-run attempts for the first head SHA after implementation completion; count cancelled infrastructure failures separately | Rises while coverage, mutation strength, review findings, and change-failure rate hold | Rerunning until green, weakening checks, delaying CI until local certainty, or excluding flaky failures silently |
| Review time per PR | Hours from ready-for-review to final required approval, excluding documented author-blocked periods | Use PR ready, review, push, and approval events; report median and p90 by risk class | Falls as evidence quality improves, without shorter superficial reviews or more escapes | Marking ready late, approving before reading, or moving discussion off-platform |
| Change-failure rate | Production deployments causing an incident, rollback, hotfix, or service impairment within the defined attribution window, divided by production deployments | Join deploy SHA and time to incident, rollback, and hotfix records; publish the attribution window | Stable or falling as deployment frequency increases | Narrow incident definitions, missing deploy linkage, avoiding rollback labels, or batching releases |
| Eval pass rate | Passed eval cases divided by all valid cases in a run, with the case-set and configuration version fixed | `passed / (passed + failed)` from CI; report invalid and flaky cases separately | Meets the reviewed threshold on discriminating cases; stable across configuration changes | Deleting hard cases, relaxing graders, repeated sampling, or changing fixtures with the config |
| Incident-to-permanent-eval time | Hours from incident start to merge of a linked regression eval that would detect the relevant failure class | Join incident ID in eval metadata to eval merge timestamp | Falls; high-severity incidents receive a case before corrective action closes | Adding a trivial unrelated case or marking a non-discriminating check as permanent |
| Regressions caught in CI versus production | Confirmed regressions first found by CI divided by all confirmed regressions first found in CI or production | Classify the earliest trustworthy detection event for each regression ID | CI share rises while total production regressions fall | Overcounting minor CI issues, underreporting production defects, or duplicating one defect into many CI records |

An eval pass rate without case-set version is not comparable.

Store the exact cases, graders, model, tools, permissions, and configuration SHA for every run.

## Deploy indicators

| Indicator | Precise definition | Compute from Git or workflow data | What good looks like | How it gets gamed |
| --- | --- | --- | --- | --- |
| Time to first review | Minutes from PR ready-for-review to the first substantive agent or human review event | Use PR timeline; exclude bot acknowledgements and label-only events | Falls to minutes for automated first pass while Important precision remains acceptable | Posting an empty review, counting a status message, or marking ready late |
| Review comments resolved without human branch edits | Agent-addressed review threads followed by an agent-authored fix and resolution, divided by all resolved review threads requiring code changes | Join review thread, actor identity, commits, and resolution event | Rises for routine fixes while code-owner approval and escape rate remain sound | Reclassifying human-assisted fixes, resolving without fixing, or avoiding comments |
| Pre-merge versus escaped defects and vulnerabilities | Confirmed material findings first caught before merge compared with confirmed findings first caught after deployment | Deduplicate findings by root cause; join PR review, scanners, incidents, and external reports | More issues caught earlier and fewer escape in absolute terms | Inflating low-value pre-merge findings or suppressing external and production reports |
| Approval-gate wait time | Minutes from a hook or environment request entering `ask` state to allow or block verdict, grouped by gate | Subtract timestamps in hook telemetry or deployment environment events; report p50 and p95 | Predictable and within service-level expectations without click-through approval | Auto-approving, requesting approval prematurely, or bypassing the instrumented gate |
| Gate violations reaching production | Count of production events that violated a declared gate condition in the measurement period | Join incidents and audit findings to hook, branch, and release records | Zero; every event triggers control repair and an eval | Narrowing the definition, recording exceptions after the fact, or failing to audit bypass paths |
| Pipeline failures triaged without paging a human | Failed pipeline runs that received a complete automated classification within the time limit and required no human page, divided by eligible failures | CI job results plus paging events; define eligible classes before measurement | Rises while incorrect triage and time-to-recovery do not worsen | Restricting eligibility after results, avoiding pages when needed, or accepting vague triage |

### DORA measures

The playbook names DORA measures as lagging deployment indicators.

Use the definitions already adopted by the organization and do not silently change them during an AI rollout.

At minimum, track:

| Measure | Precise local computation | What good looks like | How it gets gamed |
| --- | --- | --- | --- |
| Deployment frequency | Successful production deployments per service per day or week | Increases for comparable services without worse stability | Splitting no-op deploys or counting environments other than production |
| Lead time for changes | Median and p85 from code commit to successful production deployment | Falls without moving work before the measured commit | Committing late, squashing away waiting, or excluding long-running changes |
| Change-failure rate | Failed or impairing production deployments divided by all production deployments | Falls or holds while frequency rises | Underreporting incidents or changing the attribution window |
| Failed-deployment recovery time | Median and p85 from deployment-caused impairment detection to service restoration | Falls through tested rollback and diagnosis | Declaring recovery before users recover or excluding partial degradation |

Reliability targets such as service-level objectives remain essential context.

Fast delivery is not healthy when the service misses its reliability objective.

## Maintain indicators

| Indicator | Precise definition | Compute from Git or workflow data | What good looks like | How it gets gamed |
| --- | --- | --- | --- | --- |
| Band-breach-to-intent time | Minutes from deterministic `bands.yaml` breach timestamp to first committed intent in the triage queue | Join detector event ID to intent metadata and Git add timestamp | Falls substantially while false-positive and dismissal rates remain manageable | Creating empty intents, delaying breach timestamps, or suppressing noisy breaches |
| Findings becoming merged fixes | Unique maintain findings linked to a merged corrective PR divided by triaged findings classified `fix now` or `schedule` whose due window ended | Join finding IDs to PRs; report dismissals and open findings separately | Appropriate to finding quality; trend matters more than a universal high rate | Marking difficult findings dismissed, opening cosmetic fixes, or excluding overdue items |
| Repeat incidents of the same class | Confirmed incidents whose root-cause class matches a prior incident after its corrective action merged | Incident taxonomy plus linked corrective merge time | Falls; every repeat prompts review of the test, eval, skill, hook, or band | Fragmenting taxonomy so incidents look unique or using an overly broad "other" class |

Track dismissal reason and detector precision with these signals.

A fast breach-to-intent loop that floods on-call with false positives is unhealthy.

### Scheduled scan indicators

| Indicator | Precise definition | Compute from Git or workflow data | What good looks like | How it gets gamed |
| --- | --- | --- | --- | --- |
| Connected repositories on a scan schedule | Repositories with a successful qualifying scan inside their declared schedule window divided by repositories in scan scope | Join approved inventory to scan history; count a repository only when its scheduled run completed | Approaches the agreed scope while failures, cost, and finding ownership remain visible | Shrinking the inventory, counting configured but failed schedules, or excluding large repositories |
| Finding-to-review-gate time | Hours from validated scheduled-scan finding creation to the linked patch PR becoming ready for review | Join finding ID to PR metadata; report median and p90 by severity; exclude explicitly dismissed findings from this duration but report them separately | Falls for bounded findings without lower patch quality or hidden backlog | Opening empty draft PRs, delaying validation timestamps, or dismissing slow findings |
| Scheduled-scan versus production vulnerabilities | Confirmed vulnerability classes first found by a scheduled scan compared with those first found in production or by external report | Deduplicate by vulnerability root cause; classify earliest trustworthy source from scan, incident, and disclosure systems | Scheduled detection share rises while absolute production and external discoveries fall | Inflating low-severity scan findings, underreporting external reports, or changing severity thresholds |
| Findings per scan trend | Validated, non-duplicate findings per completed scan for repositories with at least three comparable runs | Normalize by repository and material code change; preserve model, scope, and rule versions | Declines as fixes and evals accumulate, or changes are explained by broader coverage | Narrowing scan scope, dismissing without reason, switching models, or deduplicating aggressively |

## Guardrail metrics

Every improvement dashboard should display guardrails beside the target metric.

| Target movement | Required guardrails |
| --- | --- |
| Faster intent capture | Intent survival, late intent edits, product-owner sample quality |
| Faster design | Requirements rework, policy conflicts found late, production escapes |
| Higher first-pass merge | Review findings, rework cycles, plan/diff match, change-failure rate |
| More concurrent sessions | Review latency, Important precision, rework, sustainable workload survey |
| Higher CI success | Test coverage quality, flaky rate, mutation or fault-seeding signal, escapes |
| Faster review | Substantive finding rate, sampled review quality, production defects |
| More autonomous triage | Triage correctness, missed pages, recovery time, model cost |
| Faster breach response | Detector precision, dismissal rate, on-call load, repeat incidents |

## Query examples

Find the first commit for each artifact path:

```sh
git log --diff-filter=A --format='%cI%x09%H' -- .sdlc/<slug>/intent.md
git log --diff-filter=A --format='%cI%x09%H' -- .sdlc/<slug>/spec.md
git log --diff-filter=A --format='%cI%x09%H' -- .sdlc/<slug>/plan.md
```

Find later specification rework:

```sh
git log --format='%cI%x09%H%x09%s' -- .sdlc/<slug>/spec.md
```

Export pull-request timestamps and review events:

```sh
gh pr list --state merged --limit 100 --json number,createdAt,mergedAt,reviews,commits,labels
```

Export check runs for an exact commit:

```sh
gh api repos/{owner}/{repo}/commits/<sha>/check-runs
```

These commands expose source events; a production metric pipeline should normalize them into the event model and preserve timezone-aware timestamps.

## Reporting cadence

Review flow metrics weekly at the team level.

Review quality, eval, and production outcomes monthly or when sample size is sufficient.

Review every gate violation and high-severity repeat incident immediately.

Keep definitions in version control and annotate dashboard changes.

Publish confidence intervals or sample counts when cohorts are small.

Do not turn natural variation into a target chase.

## Anti-gaming policy

Never attach a metric target to an individual quota.

Never reward fewer review comments, more commits, more PRs, more agent sessions, or higher acceptance in isolation.

Never remove failed, rejected, dismissed, or slow work from historical data to improve a trend.

Never change a definition without backfilling history or marking the series break.

Sample the underlying artifacts and outcomes, not only the dashboard.

Invite teams to report where a metric creates the wrong incentive.

When a signal becomes a target and stops describing reality, retire or redesign it.

The desired outcome is a process that learns quickly and fails safely, not a chart that is always green.
