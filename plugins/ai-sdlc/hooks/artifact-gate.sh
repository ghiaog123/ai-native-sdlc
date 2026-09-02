#!/usr/bin/env bash
set -euo pipefail

# PreToolUse hook: require a committed plan before source-code writes.
PAYLOAD="$(cat || true)"
TARGET_PATH="$(printf '%s' "$PAYLOAD" | python3 -c '
import json, sys
try:
    data = json.load(sys.stdin)
except Exception:
    raise SystemExit(0)
obj = data.get("tool_input", data)
for key in ("file_path", "path", "target_path"):
    value = obj.get(key) if isinstance(obj, dict) else None
    if isinstance(value, str):
        print(value)
        break
' 2>/dev/null || true)"

# An unknown payload must never block work.
[[ -n "$TARGET_PATH" ]] || exit 0
ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
[[ -d "$ROOT/.sdlc" ]] || exit 0
[[ -e "$ROOT/.sdlc/OPTOUT" ]] && exit 0

case "$TARGET_PATH" in
  "$ROOT"/.sdlc/*|.sdlc/*|*.md|*.mdx|*.txt|*.rst|*.adoc|*.yaml|*.yml|*.json|*.toml|*.ini|*.cfg|*.conf|*/docs/*|docs/*|*/test/*|test/*|*/tests/*|tests/*|*/__tests__/*|__tests__/*|*/fixtures/*|fixtures/*|*/config/*|config/*|*/.github/*|.github/*)
    exit 0
    ;;
esac

# A plan is eligible only once it is in the current committed Git tree; acceptance
# remains a separate human gate.
shopt -s nullglob
for plan_path in "$ROOT"/.sdlc/*/plan.md; do
  plan_rel="${plan_path#"$ROOT"/}"
  if git -C "$ROOT" cat-file -e "HEAD:$plan_rel" >/dev/null 2>&1; then
    exit 0
  fi
done

echo "AI SDLC artifact gate: blocked source-code write to $TARGET_PATH; create and commit .sdlc/<change>/plan.md first (or add .sdlc/OPTOUT)." >&2
exit 2
