#!/usr/bin/env bash
# Checks the artifact gate's fast-path branch and that the ordinary path still works.
# Run it from anywhere: bash plugins/ai-sdlc/hooks/test-artifact-gate.sh
set -uo pipefail

HOOKS="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
failures=0

REVIEW_MD='# Review instructions

## Sensitive paths

```text
CLAUDE.md
REVIEW.md
bands.yaml
src/billing/*
```

## Do not report
Nothing.'

# repo <name> -- then one "<slug>:<plan body>" per remaining argument
repo() {
  local name="$1"; shift
  local dir="$WORK/$name" slug body
  mkdir -p "$dir/src/billing"
  git init -q "$dir"
  git -C "$dir" config user.email test@example.com
  git -C "$dir" config user.name test
  printf '%s\n' "$REVIEW_MD" > "$dir/REVIEW.md"
  printf 'metric: x\n' > "$dir/bands.yaml"
  echo placeholder > "$dir/CLAUDE.md"
  echo placeholder > "$dir/src/app.ts"
  echo placeholder > "$dir/src/billing/charge.ts"
  for spec in "$@"; do
    slug="${spec%%:*}"; body="${spec#*:}"
    mkdir -p "$dir/.sdlc/$slug"
    printf '%s\n' "$body" > "$dir/.sdlc/$slug/plan.md"
  done
  git -C "$dir" add -A
  git -C "$dir" commit -qm fixture
  echo "$dir"
}

expect() {
  local label="$1" dir="$2" path="$3" want="$4" got
  printf '{"tool_input":{"file_path":"%s"}}' "$path" \
    | (cd "$dir" && bash "$HOOKS/artifact-gate.sh" >/dev/null 2>&1)
  got=$?
  if [[ "$got" == "$want" ]]; then
    echo "ok   $label"
  else
    echo "FAIL $label (want exit $want, got $got)"
    failures=$((failures + 1))
  fi
}

expect_patch() {
  local label="$1" dir="$2" patch="$3" want="$4" cwd="${5:-$2}" got
  printf '%s' "$patch" \
    | python3 -c 'import json, sys; print(json.dumps({"tool_name": "apply_patch", "cwd": sys.argv[1], "tool_input": {"command": sys.stdin.read()}}))' "$cwd" \
    | (cd "$dir" && bash "$HOOKS/artifact-gate.sh" >/dev/null 2>&1)
  got=$?
  if [[ "$got" == "$want" ]]; then
    echo "ok   $label"
  else
    echo "FAIL $label (want exit $want, got $got)"
    failures=$((failures + 1))
  fi
}

FAST_PLAN='# Plan: typo

## Fast path
Declared low-risk by: owner. Reason: copy only.

## Files that change
- `src/app.ts`
- `CLAUDE.md`
- `REVIEW.md`
- `bands.yaml`
- `src/billing/charge.ts`'

FULL_PLAN='# Plan: ordinary

## Files that change
- `src/app.ts`
- `src/with space.ts`
- `CLAUDE.md`
- `REVIEW.md`
- `src/billing/charge.ts`'

ROOT_ONLY_PLAN='# Plan: root file

## Files that change
- `root/*`'

fast="$(repo fast "change:$FAST_PLAN")"
full="$(repo full "change:$FULL_PLAN")"
both="$(repo both "quick:$FAST_PLAN" "deep:$FULL_PLAN")"
root_only="$(repo root-only "change:$ROOT_ONLY_PLAN")"
bare="$(repo bare)"

# A fast-path plan admits its own ordinary files.
expect "fast: admits a listed source file"                 "$fast" src/app.ts               0
# ...and nothing sensitive, however the declaration lists it.
expect "fast: refuses built-in protected CLAUDE.md"        "$fast" CLAUDE.md                2
expect "fast: refuses unlisted .github/workflows"          "$fast" .github/workflows/ci.yml 2
expect "fast: refuses REVIEW.md, the list itself"          "$fast" REVIEW.md                2
expect "fast: refuses bands.yaml from REVIEW.md"           "$fast" bands.yaml               2
expect "fast: refuses a project pattern src/billing/*"     "$fast" src/billing/charge.ts    2

# The ordinary path is unchanged.
expect "full: admits a listed protected file"              "$full" CLAUDE.md                0
expect "full: admits REVIEW.md when listed"                "$full" REVIEW.md                0
expect "full: admits a listed source file"                 "$full" src/app.ts               0
expect "full: refuses an unlisted file"                    "$full" src/other.ts             2

# Two plans in flight: a full plan covering the path still wins, whatever glob order.
expect "both: full plan covers CLAUDE.md"                  "$both" CLAUDE.md                0
expect "both: neither plan covers an unlisted file"        "$both" src/other.ts             2

# The heading is read from HEAD, so deleting it locally must not lift the restriction.
sed -i.bak '/^## Fast path$/d' "$fast/.sdlc/change/plan.md"
expect "fast: heading deleted uncommitted still refuses"   "$fast" CLAUDE.md                2

# Codex sends apply_patch in tool_input.command, including every file in one call.
expect_patch "patch: listed source and docs allowed" "$full" $'*** Begin Patch\n*** Update File: src/app.ts\n@@\n-old\n+new\n*** Add File: docs/example.md\n+example\n*** End Patch' 0
expect_patch "patch: second unlisted file blocks call" "$full" $'*** Begin Patch\n*** Update File: src/app.ts\n@@\n-old\n+new\n*** Update File: src/other.ts\n@@\n-old\n+new\n*** End Patch' 2
expect_patch "patch: added unlisted source blocked" "$full" $'*** Begin Patch\n*** Add File: src/other.ts\n+new\n*** End Patch' 2
expect_patch "patch: deleted sensitive file blocked" "$fast" $'*** Begin Patch\n*** Delete File: CLAUDE.md\n*** End Patch' 2
expect_patch "patch: move destination checked" "$full" $'*** Begin Patch\n*** Update File: src/app.ts\n*** Move to: src/other.ts\n@@\n-old\n+new\n*** End Patch' 2
expect_patch "patch: move source checked" "$full" $'*** Begin Patch\n*** Update File: src/other.ts\n*** Move to: src/app.ts\n@@\n-old\n+new\n*** End Patch' 2
expect_patch "patch: path with spaces preserved" "$full" $'*** Begin Patch\n*** Add File: src/with space.ts\n+new\n*** End Patch' 0
expect_patch "patch: unknown directive rejected" "$full" $'*** Begin Patch\n*** Bogus File: src/app.ts\n*** End Patch' 2
expect_patch "patch: incomplete payload rejected" "$full" $'*** Begin Patch\n*** Update File: src/app.ts' 2
expect_patch "patch: cwd resolves approved subdirectory path" "$full" $'*** Begin Patch\n*** Add File: app.ts\n+new\n*** End Patch' 0 "$full/src"
expect_patch "patch: cwd does not authorize root-only path" "$root_only" $'*** Begin Patch\n*** Add File: root/app.ts\n+new\n*** End Patch' 2 "$root_only/src"
expect_patch "patch: malformed payload inert without .sdlc" "$bare" $'*** Begin Patch\n*** Bogus File: app.ts\n*** End Patch' 0
: > "$full/.sdlc/OPTOUT"
expect_patch "patch: malformed payload inert with OPTOUT" "$full" $'*** Begin Patch\n*** Bogus File: app.ts\n*** End Patch' 0

[[ "$failures" == 0 ]] && echo "all checks passed" || echo "$failures check(s) failed"
exit "$((failures > 0))"
