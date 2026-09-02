---
name: sdlc-deploy
description: Prepare a verified change for human PR review by running REVIEW.md passes through the sdlc-reviewer subagent and posting ranked findings. Do NOT use for intent or scope decisions, accepting organizational risk, self-approval, merging, deploying, or bypassing branch protection.
---

# SDLC Deploy

Run Stage 5 of 6 in the AI-Native SDLC playbook described in `docs/PLAYBOOK.md`.

## Purpose

Prepare the pull request and review evidence. This stage posts findings and stops
for a human; it never merges or deploys.

Do not judge whether the original intent was worthwhile. Do not accept risk for the
organization.

## Entry gate

Proceed only when `sdlc-test` has completed with green verification evidence and
the code is ready for review.

Read the test report. Confirm it includes actual passing output and applicable
eval evidence for any changed `CLAUDE.md`, skill, or hook.

If verification is incomplete, stale after changes, missing, or red, return to
`sdlc-test` and stop.

## Procedure

0. Identify the slug for this change and read `.sdlc/<slug>/spec.md` and
   `.sdlc/<slug>/plan.md`. The PR description must link them, so a reviewer can see
   the accepted intent, spec, and plan behind the diff without leaving the PR.
1. Locate the project's `REVIEW.md`.
2. If it exists, read every applicable review pass and its nit cap.
3. If it does not exist, record that fact and continue with the required review
   passes using sound judgment.
4. Assemble the code changes, verification evidence, and `REVIEW.md` instructions.
5. Invoke the `sdlc-reviewer` subagent with the changes and the review passes:
   Bugs, Security, and Compliance.
6. Require the subagent to rank each finding as `Important` or `Nit`.
7. Enforce the nit cap from `REVIEW.md`; for example, if it says `max 5 nits`,
   include at most five nits.
8. If `REVIEW.md` has no cap, use judgment and keep nits actionable.
9. Create or update the pull request with context, test evidence, and findings.
10. Post the findings as a PR comment or include them in the PR body.
11. Cite the review findings and explicitly stop for human approval.

Give the reviewer only evidence and review scope, not authority to waive risks.

## Reviewer request

Tell the `sdlc-reviewer` subagent to inspect the actual diff and report:

- Bugs found by the Bugs pass.
- Security concerns found by the Security pass.
- Compliance concerns found by the Compliance pass.
- Severity for each finding: `Important` or `Nit`.
- File and line references where available.
- Concise rationale and a suggested remediation when appropriate.

Pass through the project's `REVIEW.md` rules. Do not replace them with an invented
review rubric.

If no findings exist, record that the passes found none rather than fabricating
comments.

## Findings and PR content

Separate Important findings from Nits in the PR content.

Keep the number of nits within the `REVIEW.md` cap. Important findings are not
nits and must not be hidden by the cap.

Include test evidence from Stage 4 so a human can evaluate the change.

State whether `REVIEW.md` was found and, if so, which passes governed the review.

Do not alter code merely to make findings disappear without returning to the test
stage for fresh verification.

## Running in CI

The same review runs unattended. In CI, invoke Claude non-interactively inside a
sandbox with filesystem and network isolation, scoped to the repository and the
review passes. A sandboxed CI run posts findings exactly as an interactive run does;
it gains no authority to merge, deploy, or waive a finding.

Treat a CI review as evidence for the human reviewer, never as a substitute for one.

## Prohibitions

Never merge the PR.

Never deploy the code.

Never bypass, disable, or work around the approval-gate hook. It fires on its own,
and branch protection enforces the merge gate; an agent cannot override either.

Never accept a security, compliance, operational, or product risk on behalf of the
organization.

Never treat your own PR post as human approval.

## Exit gate

Post the PR and cite the ranked findings. Then explicitly stop.

The next step must be a human approval, either through branch protection or an
explicit `LGTM`.

If human approval has not happened, do not hand off to maintenance.

## Handoff

Only once a human approves merge through branch protection or explicit `LGTM`,
proceed to `sdlc-maintain` after the code is deployed.

Carry forward the PR link, approval evidence, review findings, and deployment
identity if available.
