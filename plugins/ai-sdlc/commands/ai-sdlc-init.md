---
description: Scaffold this project for the AI-native SDLC loop without replacing existing project guidance.
---

1. Find the repository root and inspect `package.json`, `Makefile`, `pyproject.toml`, `go.mod`, and `Cargo.toml` when present. Extract the actual build, test, and lint commands from the project; do not invent commands or leave placeholders.
2. Create `.sdlc/` if it does not exist. Add a short `.sdlc/README.md` only when the project has no local workflow instructions, explaining that each change gets a slug directory containing `intent.md`, `spec.md`, and `plan.md`.
3. Generate project-specific `CLAUDE.md` from the inspected commands and the repository's existing conventions and architecture. If `CLAUDE.md` already exists, never overwrite user-authored content: show a unified diff for proposed guidance additions and ask for an explicit human decision before making any change outside the AI-Native SDLC block below.
4. Copy the plugin's `REVIEW.md` and `bands.yaml` templates into `.sdlc/` only if each destination does not already exist. Existing files are authoritative; show a diff and offer a merge proposal instead of replacing them.
5. After creating the project's `.sdlc/` directory and files, add this exact block to the project's `CLAUDE.md`:

   <!-- ai-sdlc:begin -->
   ## AI-Native SDLC Loop

   This repository uses the AI-Native SDLC loop (https://claude.com/blog/the-ai-native-sdlc-playbook).

   - Artifacts live in `.sdlc/<slug>/`: intent.md, spec.md, plan.md
   - No source code is written for a change without an accepted plan.md
   - No gate is ever self-approved by the agent
   - Six stage skills guide the loop: sdlc-plan → sdlc-design → sdlc-build → sdlc-test → sdlc-deploy → sdlc-maintain
   - Loop is always active once .sdlc/ exists; toggle with .sdlc/OPTOUT
   <!-- ai-sdlc:end -->

   If the markers already exist, replace only the text from `<!-- ai-sdlc:begin -->` through `<!-- ai-sdlc:end -->`; otherwise append the block to the end of `CLAUDE.md`. Never clobber user content outside those markers.
6. Offer to wire the plugin hooks into `.claude/settings.json`. Preserve existing settings and hooks, and show the exact JSON merge before writing.
7. Print a completion summary: created paths, skipped existing paths, proposed diffs, detected commands, and the items a human must complete (team conventions, architecture notes, production bands, and protected deployment targets).
8. Re-running this command must be safe and idempotent: it may create missing files or replace only the marked AI-Native SDLC block; it must not clobber user-authored guidance.
