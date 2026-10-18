# Review instructions

## Passes

Every review runs independent passes and reports only evidence-backed findings in
changed code, changed plan, or its immediate behavior.

**Plan** — runs at Stage 3 against `plan.md` before any code is written, and is the only
pass that runs there. Check that every requirement in the accepted spec appears in the
work — or, for a change on the fast path, which has no spec, that the work stays inside
the scope and reason its `## Fast path` section declares, and that nothing in it reaches
a sensitive path; that `Proof` names verification that would actually fail if the requirement broke,
rather than restating that tests exist; that `Order of work` has no step depending on a
later one; that `Risks` covers migration, compatibility, and revert; and that `Files that
change` matches the real scope. That last item is not cosmetic: the artifact gate admits
source writes from this list, so a missing entry blocks the author mid-implementation and
an over-broad entry widens what the gate will admit.

**Bugs** — behavior that can return the wrong result, lose or corrupt data, break an
existing supported flow, mishandle retries or concurrency, or leave a failure path unsafe.
Verify boundaries, defaults, error handling, and compatibility with the accepted spec.

**Security** — missing authorization at a trust boundary, injection, secret exposure,
unsafe deserialization, insecure cryptography, privilege escalation, sensitive-data
logging, or an externally reachable denial-of-service path. Treat new dependencies and
public endpoints as security-relevant.

**Compliance** — violations of declared data classification, consent, retention, audit
logging, access-control, accessibility, or regulatory controls. If no project rule
applies, state that this pass found no applicable requirement rather than inventing one.

## Reviewer

Stage 3 plan review: `codex-plan-review`
Stage 5 code review: `sdlc-reviewer`

Name the reviewer each stage uses. `sdlc-reviewer` is the subagent the plugin ships and
always works. An external reviewer such as `codex-plan-review` is stronger where it is
installed; when it is unavailable, fall back to `sdlc-reviewer` running the `Plan` pass
and record the fallback in `review-findings.md` rather than skipping the review.

## Depth

Depth: Standard

This is the repository default. Override it per area by naming a path and a level,
one per line, and the deepest matching level wins:

```text
src/billing/*        Deep
docs/*               Quick
```

**Quick** — Plan pass at Stage 3; Bugs and Security at Stage 5. One round, nits off.
A change on the fast path runs at Quick unless it reaches a sensitive path.

**Standard** — every pass, nits capped as below, the full round budget.

**Deep** — every pass, plus: trace each changed function to its callers, check the change
against the two most recent incidents touching this area, and report Minor findings that
Standard would leave out. For code where one missed bug is expensive.

The Security pass runs at every depth and is never reduced. Any change touching a path in
**Sensitive paths** runs at Standard or deeper, whatever this setting says.

## Sensitive paths

A change touching any of these is never low-risk, never takes the fast path, and always
needs a human approval:

```text
CLAUDE.md
REVIEW.md
bands.yaml
.claude/settings.json
.claude/skills/*
.claude/hooks/*
.github/workflows/*
.github/actions/*
```

Extend this list with the paths this project cannot afford to have changed without a
person reading the diff: authentication, authorization, billing, migrations, the
installer, the update path. `REVIEW.md` is on the list so the list itself cannot be
widened or emptied on the fast path.

## Rounds

Round cap: 3.

A review round is one review followed by the author's fixes. Rounds are recorded in
`.sdlc/<slug>/review-findings.md`.

**Re-review the diff, not the change.** After round 1, review only what changed since the
previous round's recorded SHA.

**Never post a finding twice.** Check the earlier rounds in `review-findings.md` first and
report the suppressed count instead of the finding.

**Report the class, not the line.** When the same defect appears at several call sites,
report it once as a class and require every instance to be fixed. A fix at one call site
that leaves its siblings broken does not resolve the finding.

**Stop at the cap.** When a fourth round would be needed, do not review again. Say so, and
send the author back to `plan.md` to reconsider the approach. Repeated rounds that keep
finding more mean the approach is wrong, not that the review is working.

## Verifier

Before any finding is posted — at Stage 3 against the plan, and at Stage 5 against the
diff — a second read-only reviewer sees the finding and the code or plan it cites, with
no access to the reasoning that produced it, and judges whether the failure is real.
Findings it rejects are not posted; the rejected count is recorded per round.

The verifier judges reality, not importance. It never upgrades, downgrades, or rewrites a
finding, and it never adds one.

## What Important means here

**Important** means a realistic production failure affecting correctness, security,
compliance, availability, or customer data. It blocks merge until fixed or explicitly
accepted by the responsible human.

**Minor** means a bounded issue that should be fixed before release when practical.

**Nit** means a non-blocking clarity improvement.

**Pre-existing** means a real defect in code this change did not introduce. It does not
block merge and is not counted against the author, but it is always listed in the PR so a
human decides what happens to it. A pre-existing defect that is a security finding is
reported under Security at its real severity and blocks merge like any other: the tag
changes who is answerable, never whether the change ships.

## Cap the nits

Report at most five Nits. Important findings are never counted against this cap and are
never suppressed by it. A review that returns two Important findings and no Nits is a
better review than one that returns twenty entries.

## Fix a repeat at its source

A finding class recorded in two or more changes must be encoded where it cannot recur: a
line in `CLAUDE.md`, a lint rule, or a rule in this file. List it under **Recurring** in
`review-findings.md` with what encodes it. An unencoded recurring class holds the Stage 5
exit gate.

## Do not report

Generated code. Vendored dependencies. Formatting that the configured formatter or linter
already owns. Subjective style preferences with no correctness, security, compliance, or
maintenance consequence.
