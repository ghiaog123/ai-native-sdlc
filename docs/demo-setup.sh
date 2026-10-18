# Builds the scenario behind docs/demo.gif, so the recording stages nothing but the
# scene. Source it from a repository checkout, then call `gate <path>`:
#
#   source docs/demo-setup.sh
#   gate README.md     # 0, the plan covers it
#   gate REVIEW.md     # 2, the fast path cannot reach a sensitive path
#
# It works in a throwaway git repository under $TMPDIR and touches nothing else.

GATE="${GATE:-$PWD/plugins/ai-sdlc/hooks/artifact-gate.sh}"
[[ -f "$GATE" ]] || { echo "set GATE to plugins/ai-sdlc/hooks/artifact-gate.sh" >&2; return 1; }

cd "$(mktemp -d)" || return 1
git init -q .
git config user.email demo@example.com
git config user.name demo
mkdir -p .sdlc/typo-fix

cat > REVIEW.md <<'EOF'
# Review instructions

## Sensitive paths

```text
CLAUDE.md
REVIEW.md
bands.yaml
```
EOF

cat > .sdlc/typo-fix/plan.md <<'EOF'
# Plan: fix a typo in the README

## Fast path
Declared low-risk by: hieu. Reason: one misspelled word in the install section.
Sensitive-path check: no file in REVIEW.md Sensitive paths is touched.

## Files that change
- README.md
EOF

echo placeholder > README.md
echo placeholder > CLAUDE.md
git add -A
git commit -qm "a change in flight"

gate() {
  printf '{"tool_input":{"file_path":"%s"}}' "$1" | bash "$GATE"
  echo "exit $?"
}
