#!/usr/bin/env bash
set -euo pipefail

ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
[[ -d "$ROOT/.sdlc" && ! -e "$ROOT/.sdlc/OPTOUT" ]] || exit 0

STATE="${CLAUDE_PLUGIN_ROOT:-${PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}}/hooks/sdlc-state.sh"
"$STATE" --short
