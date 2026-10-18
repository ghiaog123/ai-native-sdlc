# Security policy

## What this project is

`ai-sdlc` is a plugin for Claude Code and Codex. It ships shell hooks, Markdown
skills, agent definitions and templates. It has no runtime service, no network
calls, and no dependencies beyond `bash`, `git` and `python3`.

Two hooks can block a tool call: `artifact-gate.sh` refuses a source write that no
approved `plan.md` covers, and `prod-guard.sh` requires explicit human
authorization for deploy and teardown command shapes. Both are inert unless the
repository being worked in has a `.sdlc/` directory.

## What is in scope

A report is in scope when it shows one of these:

- A way to make `artifact-gate.sh` admit a write it should refuse — in particular
  a write to a path listed under **Sensitive paths** in `REVIEW.md` while a
  fast-path change is active, or a write that no active plan covers.
- A way to make `prod-guard.sh` pass a command it should hold for authorization.
- Command injection, path traversal or unsafe interpolation in any hook, reachable
  from a tool-call payload, a file path, a plan, or repository contents.
- A prompt injection in reviewed content — a diff, commit message, dependency name,
  or source comment — that causes `sdlc-reviewer` to suppress a finding, claim a
  human gate has passed, or act on instructions found in that content.
- Anything that causes a hook to write, delete or exfiltrate data outside the
  repository it is invoked in.
- A secret committed to this repository.

## What is not in scope

- **Hooks are not a security boundary on their own.** They are a guardrail against
  an agent acting outside an approved plan, not a sandbox. `prod-guard.sh` matches
  common command shapes and can be worked around by a determined operator who
  rewrites the command. The real controls are IAM, RBAC, branch protection, deploy
  approvals and sandboxing; the plugin says so in its own documentation. A report
  that a hook can be bypassed by someone who already has shell access and intends
  to bypass it describes the design, not a defect.
- A finding that requires modifying the plugin's own files on disk first.
- A missing control in a repository that has not run `/ai-sdlc-init`, since every
  hook is inert without `.sdlc/`.
- Anything in a consuming project's own `REVIEW.md`, `bands.yaml` or `CLAUDE.md`,
  which that project owns.

## Reporting a vulnerability

Report privately through GitHub Security Advisories:

**<https://github.com/ghiaog123/ai-native-sdlc/security/advisories/new>**

Please do not open a public issue for a vulnerability, and do not include real
credentials in a report.

Include what you have: the hook or skill involved, the payload or repository state
that triggers it, what you expected to happen, and what happened instead. A minimal
repository that reproduces the problem is the most useful thing you can send, since
every hook's behaviour depends on the `.sdlc/` state around it.

## What to expect

Acknowledgement within 7 days. An assessment, with a severity and a fix or a
rejection with reasons, within 30 days.

This is a volunteer-maintained project with no paid support and no bug bounty.
Timelines are a good-faith commitment, not a contractual guarantee.

Fixes land through the project's own loop: a confirmed report becomes an
`intent.md`, and the change carries a regression check in
`plugins/ai-sdlc/hooks/` that fails if the defect returns. Credit is given in the
advisory unless you ask otherwise.

## Supported versions

The latest commit on `main` is supported. There are no maintained release
branches, so please confirm a finding against `main` before reporting.
