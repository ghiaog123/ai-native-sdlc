#!/usr/bin/env bash
# Checks stage derivation: the reserved evals directory, fast-path changes, and that a
# plan-only review-findings.md is not mistaken for an open pull request.
# Run it from anywhere: bash plugins/ai-sdlc/hooks/test-sdlc-state.sh
set -uo pipefail

HOOKS="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
failures=0

check() {
  local label="$1" got="$2" want="$3"
  if [[ "$got" == *"$want"* ]]; then
    echo "ok   $label"
  else
    echo "FAIL $label"
    echo "       want substring: $want"
    echo "       got:            $got"
    failures=$((failures + 1))
  fi
}

refute() {
  local label="$1" got="$2" unwanted="$3"
  if [[ "$got" != *"$unwanted"* ]]; then
    echo "ok   $label"
  else
    echo "FAIL $label (output should not contain '$unwanted')"
    echo "       got: $got"
    failures=$((failures + 1))
  fi
}

dir="$WORK/repo"
mkdir -p "$dir/.sdlc/evals/reviewer/proposed" "$dir/.sdlc/ordinary" "$dir/.sdlc/quickfix" "$dir/src"
git init -q "$dir"
git -C "$dir" config user.email test@example.com
git -C "$dir" config user.name test

# An ordinary change: full artifacts, verification done, plan review recorded but no
# code round yet. It is waiting on sdlc-deploy, not on a human reading a pull request.
printf '# Intent: x\n'        > "$dir/.sdlc/ordinary/intent.md"
printf '# Specification: x\n' > "$dir/.sdlc/ordinary/spec.md"
printf '# Plan: x\n\n## Files that change\n- `src/app.ts`\n' > "$dir/.sdlc/ordinary/plan.md"
printf '# Review findings: x\n\n## Round 1 — Plan — `abc`\n\nNo findings.\n' \
  > "$dir/.sdlc/ordinary/review-findings.md"
printf 'all green\n' > "$dir/.sdlc/ordinary/test-results.md"

# A fast-path change: plan only, no intent and no spec.
printf '# Plan: typo\n\n## Fast path\nDeclared low-risk by: owner.\n\n## Files that change\n- `README.md`\n' \
  > "$dir/.sdlc/quickfix/plan.md"

echo placeholder > "$dir/src/app.ts"
git -C "$dir" add -A
git -C "$dir" commit -qm fixture

long="$(cd "$dir" && bash "$HOOKS/sdlc-state.sh" --long)"
short="$(cd "$dir" && bash "$HOOKS/sdlc-state.sh" --short)"

refute "evals is not reported as a change"            "$long"  "evals"
refute "evals does not hide the real change (--short)" "$short" "evals"
check  "plan-only findings are not an open PR"        "$long"  "ordinary	4 (Test)"
check  "fast-path change derives a stage"             "$long"  "quickfix	3 (Build)"
check  "fast-path change is named as such"            "$long"  "fast path;"

# Add a Code round: now a diff really has been reviewed, so a PR exists.
printf '\n## Round 2 — Code — `def`\n\nNo findings.\n' >> "$dir/.sdlc/ordinary/review-findings.md"
git -C "$dir" add -A
git -C "$dir" commit -qm "code round"
long2="$(cd "$dir" && bash "$HOOKS/sdlc-state.sh" --long)"
check  "a Code round does count as an open PR"        "$long2" "ordinary	5 (Deploy)"

[[ "$failures" == 0 ]] && echo "all checks passed" || echo "$failures check(s) failed"
exit "$((failures > 0))"
