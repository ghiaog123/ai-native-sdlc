#!/usr/bin/env bash
set -euo pipefail

ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
[[ -d "$ROOT/.sdlc" && ! -e "$ROOT/.sdlc/OPTOUT" ]] || exit 0

STATE="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}/hooks/sdlc-state.sh"
ROWS="$($STATE --long)"

printf '%s\n' 'AI-Native SDLC loop is active.'
printf '%s\n' 'Chain: intent.md -> spec.md -> plan.md -> code -> test -> PR -> band-watch'
printf '%s\n' 'Skills: 1 sdlc-plan | 2 sdlc-design | 3 sdlc-build | 4 sdlc-test | 5 sdlc-deploy | 6 sdlc-maintain'
printf '\n%-22s %-18s %s\n' 'Slug' 'Current stage' 'Next action / human gate'
printf '%-22s %-18s %s\n' '----------------------' '------------------' '------------------------'
if [[ -n "$ROWS" ]]; then
  shown=0
  hidden=0
  while IFS=$'\t' read -r slug stage detail next; do
    if (( shown < 16 )); then
      printf '%-22s %-18s %s\n' "$slug" "$stage" "$next"
      ((shown += 1))
    else
      ((hidden += 1))
    fi
  done <<< "$ROWS"
  (( hidden == 0 )) || printf '... %s additional slugs; run ai-sdlc-status for all.\n' "$hidden"
else
  printf '%s\n' '(no change slugs yet)'
fi
printf '\n%s\n' 'Standing rule: an agent never self-approves a gate.'
