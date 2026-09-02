#!/usr/bin/env bash
set -euo pipefail

# Derive SDLC progress from committed artifacts and the working tree; never persist state.
MODE="${1:---long}"
case "$MODE" in
  --long|--short) ;;
  *) echo "Usage: $0 [--long|--short]" >&2; exit 64 ;;
esac

ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
SDLC_DIR="$ROOT/.sdlc"
[[ -d "$SDLC_DIR" && ! -e "$SDLC_DIR/OPTOUT" ]] || exit 0

committed() {
  git -C "$ROOT" cat-file -e "HEAD:${1#"$ROOT"/}" >/dev/null 2>&1
}

code_is_dirty() {
  local entry path
  while IFS= read -r entry; do
    path="${entry:3}"
    [[ "$path" == .sdlc/* ]] || return 0
  done < <(git -C "$ROOT" status --porcelain --untracked-files=all 2>/dev/null || true)
  return 1
}

markdown_matches() {
  local slug_dir="$1" expression="$2" file line
  for file in "$slug_dir"/*.md; do
    committed "$file" || continue
    while IFS= read -r line || [[ -n "$line" ]]; do
      [[ "$line" =~ $expression ]] && return 0
    done < "$file"
  done
  return 1
}

has_evidence() {
  local slug_dir="$1" pattern
  for pattern in \
    'test-results.md' 'test-results.txt' 'test-report.md' 'verification.md' \
    'verification-results.md'; do
    [[ -f "$slug_dir/$pattern" ]] && committed "$slug_dir/$pattern" && return 0
  done
  return 1
}

has_pr() {
  local slug_dir="$1" pattern
  for pattern in 'pr.md' 'pull-request.md' 'review-findings.md'; do
    [[ -f "$slug_dir/$pattern" ]] && committed "$slug_dir/$pattern" && return 0
  done
  markdown_matches "$slug_dir" 'https://[^[:space:]]+/(pull|merge_requests)/[0-9]+'
}

is_released() {
  local slug_dir="$1" pattern
  for pattern in 'merged.md' 'deployment.md' 'deployed.md' 'release.md'; do
    [[ -f "$slug_dir/$pattern" ]] && committed "$slug_dir/$pattern" && return 0
  done
  markdown_matches "$slug_dir" '[Ss][Tt][Aa][Tt][Uu][Ss]:[[:space:]]*(merged|deployed)|(^|[[:space:]])(deployed|merged)([[:space:].,:;]|$)'
}

emit() {
  local slug="$1" stage="$2" name="$3" detail="$4" next="$5"
  if [[ "$MODE" == "--short" ]]; then
    [[ "$stage" -lt 6 ]] || return 0
    printf 'AI-SDLC: %s at stage %s (%s). %s Next gate: %s.\n' "$slug" "$stage" "$name" "$detail" "$next"
    return 0
  fi
  printf '%s\t%s (%s)\t%s\t%s\n' "$slug" "$stage" "$name" "$detail" "$next"
}

shopt -s nullglob
for slug_dir in "$SDLC_DIR"/*; do
  [[ -d "$slug_dir" ]] || continue
  slug="${slug_dir##*/}"
  intent="$slug_dir/intent.md"
  spec="$slug_dir/spec.md"
  plan="$slug_dir/plan.md"

  if [[ ! -f "$intent" ]]; then
    emit "$slug" 0 "Plan" "intent.md is absent." "write intent (sdlc-plan)"
  elif ! committed "$intent"; then
    emit "$slug" 1 "Plan" "intent.md is awaiting its acceptance commit." "product owner accepts intent"
  elif [[ ! -f "$spec" ]]; then
    emit "$slug" 1 "Plan" "intent.md is committed." "start sdlc-design"
  elif ! committed "$spec"; then
    emit "$slug" 2 "Design" "spec.md is awaiting its approval commit." "human approves spec"
  elif [[ ! -f "$plan" ]]; then
    emit "$slug" 2 "Design" "spec.md is committed." "start sdlc-build"
  elif ! committed "$plan"; then
    emit "$slug" 3 "Build" "plan.md is awaiting its approval commit." "human approves plan"
  elif is_released "$slug_dir"; then
    emit "$slug" 6 "Maintain" "change is merged or deployed." "watch for band breach"
  elif code_is_dirty; then
    emit "$slug" 3 "Build" "plan.md accepted; implementing." "finish code"
  elif ! has_evidence "$slug_dir"; then
    emit "$slug" 3 "Build" "code committed; verification evidence is absent." "run sdlc-test"
  elif ! has_pr "$slug_dir"; then
    emit "$slug" 4 "Test" "verification is green." "start sdlc-deploy"
  else
    emit "$slug" 5 "Deploy" "PR is open with verification evidence." "human approves the PR"
  fi

  if [[ "$MODE" == "--short" ]]; then
    exit 0
  fi
done

# The loop's own status must never leak out under `set -e`: a hook that exits nonzero
# is reported as a hook error and its output is discarded.
exit 0
