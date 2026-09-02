#!/usr/bin/env bash
set -euo pipefail

# This guard is opt-in per repository, exactly like every other AI-SDLC hook: the plugin
# is installed globally, so a repository that never ran /ai-sdlc-init must be untouched.
# Blocking a deploy in an unrelated repository is a worse failure than not guarding it.
ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
if [[ ! -d "$ROOT/.sdlc" ]] || [[ -e "$ROOT/.sdlc/OPTOUT" ]]; then
  exit 0
fi

# Set AI_SDLC_ALLOW_PROD=1 only after explicit human authorization to bypass this guard.
if [[ "${AI_SDLC_ALLOW_PROD:-}" == "1" ]]; then
  exit 0
fi

PAYLOAD="$(cat || true)"
COMMAND="$(printf '%s' "$PAYLOAD" | python3 -c '
import json, sys
try:
    data = json.load(sys.stdin)
except Exception:
    raise SystemExit(0)
obj = data.get("tool_input", data)
for key in ("command", "cmd"):
    value = obj.get(key) if isinstance(obj, dict) else None
    if isinstance(value, str):
        print(value)
        break
' 2>/dev/null || true)"

[[ -n "$COMMAND" ]] || exit 0
RULE=""
if [[ "$COMMAND" =~ kubectl.*--context[[:space:]]*[^[:space:]]*prod ]]; then
  RULE="kubectl with a production context"
elif [[ "$COMMAND" =~ terraform[[:space:]]+apply ]]; then
  RULE="terraform apply"
elif [[ "$COMMAND" =~ helm[[:space:]]+upgrade ]]; then
  RULE="helm upgrade"
elif [[ "$COMMAND" =~ aws.*--profile[[:space:]]*[^[:space:]]*prod ]]; then
  RULE="AWS command with a production profile"
elif [[ "$COMMAND" =~ gh[[:space:]]+release[[:space:]]+create ]]; then
  RULE="gh release create"
elif [[ "$COMMAND" =~ git[[:space:]]+push.*(protected|main|master|production|prod|release) ]]; then
  RULE="git push to a protected branch"
elif [[ "$COMMAND" =~ flyctl[[:space:]]+deploy ]]; then
  RULE="flyctl deploy"
elif [[ "$COMMAND" =~ vercel.*[[:space:]]--prod ]]; then
  RULE="vercel --prod"
elif [[ "$COMMAND" =~ (migrate|migration).*(prod|production) ]] || [[ "$COMMAND" =~ (postgres|mysql|mongodb)[^[:space:]]*(prod|production)[^[:space:]]*(migrate|migration) ]]; then
  RULE="database migration against a production URL"
fi

if [[ -n "$RULE" ]]; then
  echo "AI SDLC production guard: blocked $RULE. Explicit human authorization is required; set AI_SDLC_ALLOW_PROD=1 only after approval." >&2
  exit 2
fi

exit 0
