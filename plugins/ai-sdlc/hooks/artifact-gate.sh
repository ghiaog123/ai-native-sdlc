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

# Normalize the target path: resolve relative to repo root, collapse . and ..
NORMALIZED="$(python3 -c "
import os, sys
path = sys.argv[1]
root = sys.argv[2]
# Make absolute if relative
if not os.path.isabs(path):
    path = os.path.join(root, path)
# Normalize to collapse . and ..
path = os.path.normpath(path)
# Ensure it stays within repo
try:
    rel = os.path.relpath(path, root)
    if rel.startswith('..'):
        print(path)  # Outside repo
    else:
        print(rel)
except:
    print(path)
" "$TARGET_PATH" "$ROOT" 2>/dev/null || echo "$TARGET_PATH")"

# Files protected by governance that always require a plan, even if they match
# the general exemptions. The gate exists to prevent unauthorized changes to:
# - Agent institutional memory and policy (CLAUDE.md, .claude/*)
# - CI/CD pipelines and secrets (GitHub, GitLab, Jenkins, CircleCI, Azure)
# - Container images and deployment manifests (Docker, k8s, Helm, Terraform)
is_protected() {
    local path="$1"
    case "$path" in
        CLAUDE.md|\
        .claude/settings.json|\
        .claude/skills/*/SKILL.md|\
        .claude/hooks/*|\
        .github/workflows/*|\
        .github/actions/*|\
        .gitlab-ci.yml|\
        Jenkinsfile|\
        .circleci/*|\
        azure-pipelines.yml|\
        Dockerfile|\
        docker-compose*.yml|\
        *.tf|\
        *.tfvars|\
        k8s/*|\
        helm/*|\
        charts/*|\
        kustomize/*|\
        *deployment*.yaml|\
        *ingress*.yaml|\
        *rbac*.yaml)
            return 0
            ;;
    esac
    return 1
}

# A plan that declares "## Fast path" belongs to a change that skipped Stage 1 and
# Stage 2 on a person's low-risk declaration. Such a plan may never admit a write to
# a sensitive path, however the declaration lists it: the whole basis of the fast
# path is that the change does not reach one.
#
# Read the heading from HEAD, not the working tree. plan.md is itself exempt from
# this gate, so an agent that could delete the heading locally would otherwise lift
# the restriction on itself.
plan_is_fast_path() {
    local plan_rel="$1"
    git -C "$ROOT" show "HEAD:$plan_rel" 2>/dev/null \
        | grep -qE '^##[[:space:]]+Fast[[:space:]]path[[:space:]]*$'
}

# The project's own sensitive paths, from the fenced block under "## Sensitive paths"
# in the committed REVIEW.md. Read from HEAD for the same reason: an uncommitted edit
# must not be able to shrink the list that governs the edit.
review_sensitive_patterns() {
    git -C "$ROOT" show HEAD:REVIEW.md 2>/dev/null | python3 -I -c '
import sys
lines = sys.stdin.read().split("\n")
out, in_section, in_fence = [], False, False
for line in lines:
    if line.startswith("## "):
        if in_fence:
            break
        in_section = line.strip().lower() == "## sensitive paths"
        continue
    if not in_section:
        continue
    if line.startswith("```"):
        if in_fence:
            break
        in_fence = True
        continue
    if in_fence and line.strip():
        out.append(line.strip())
print("\n".join(out))
' 2>/dev/null || true
}

# A path no fast-path change may touch: the built-in governance list, plus whatever
# this project added to REVIEW.md.
is_sensitive() {
    local path="$1" pattern
    is_protected "$path" && return 0
    while IFS= read -r pattern; do
        [[ -n "$pattern" ]] || continue
        # shellcheck disable=SC2254 — the pattern is a glob on purpose.
        case "$path" in
            $pattern) return 0 ;;
        esac
    done <<< "$SENSITIVE_PATTERNS"
    return 1
}

# Files that are genuinely exempt and need no plan: SDLC artifacts, docs, tests
is_exempt() {
    local path="$1"
    case "$path" in
        .sdlc/*|\
        .sdlc-*|\
        docs/*|\
        *.md|\
        *.mdx|\
        *.txt|\
        *.rst|\
        *.adoc|\
        test/*|\
        tests/*|\
        *_test.*|\
        test_*.*|\
        *.spec.*|\
        __tests__/*|\
        */test/*|\
        */tests/*|\
        */__tests__/*|\
        */fixtures/*|\
        fixtures/*)
            return 0
            ;;
    esac
    return 1
}

# Check if a path is listed in a plan's "## Files that change" section
# Returns: 0 if found, 1 if not found, 2 if section doesn't exist (should allow)
path_in_plan() {
    local plan_file="$1" target_path="$2"
    local in_section=0 section_found=0
    
    while IFS= read -r line || [[ -n "$line" ]]; do
        # Enter "## Files that change" section
        if [[ "$line" =~ ^##\ Files\ that\ change ]]; then
            in_section=1
            section_found=1
            continue
        fi
        
        # Exit section at next heading
        if [[ "$in_section" == 1 && "$line" =~ ^## ]]; then
            break
        fi
        
        # Process lines in the section
        if [[ "$in_section" == 1 && -n "$line" ]]; then
            # Strip markdown list markers, backticks, and trim
            local entry="${line#*[*-] }"  # Remove list marker
            entry="${entry//\`/}"          # Remove backticks
            entry="${entry%%#*}"           # Remove inline comments
            entry="${entry%%(*}"           # Remove parenthetical notes
            entry="$(printf '%s' "$entry" | sed -e 's/^[[:space:]]*//;s/[[:space:]]*$//')"
            
            [[ -z "$entry" ]] && continue
            
            # Match by exact path
            if [[ "$entry" == "$target_path" ]]; then
                return 0
            fi
            
            # Match by basename
            local entry_base="${entry##*/}"
            local target_base="${target_path##*/}"
            if [[ -n "$entry_base" && "$entry_base" == "$target_base" ]]; then
                return 0
            fi
            
            # Match by suffix (if entry ends with /*)
            if [[ "$entry" == *'/*' ]]; then
                local entry_prefix="${entry%/*}"
                if [[ "$target_path" == "$entry_prefix"/* ]]; then
                    return 0
                fi
            fi
            
            # Match by directory prefix (if entry ends with /)
            if [[ "$entry" == */ ]]; then
                local entry_prefix="${entry%/}"
                if [[ "$target_path" == "$entry_prefix"/* ]] || [[ "$target_path" == "$entry_prefix" ]]; then
                    return 0
                fi
            fi
        fi
    done < "$plan_file"
    
    # If section doesn't exist, return 2 (allow)
    [[ "$section_found" == 0 ]] && return 2
    # If section exists but file not found, return 1 (block)
    return 1
}

# Sanitize a string for error output: strip CR/LF and control chars, truncate
sanitize_path() {
    local path="$1"
    # Strip control characters and CR/LF, then truncate to 200 chars
    printf '%s' "$path" | tr -d '\r\n\000-\037' | cut -c1-200
}

SENSITIVE_PATTERNS="$(review_sensitive_patterns)"

# Walk every active plan once (plan.md committed, slug not finished) and record what
# each one says about this path. Never break: with two plans in flight, breaking makes
# the verdict depend on glob order.
shopt -s nullglob
active_plan_found=0
path_matches_plan=0
section_missing_in_active=0
fast_path_active=0
ordinary_plan_covers_path=0
fast_path_slug=""

for plan_path in "$ROOT"/.sdlc/*/plan.md; do
    plan_rel="${plan_path#"$ROOT"/}"
    slug_dir="${plan_path%/*}"
    slug="${slug_dir##*/}"

    # Plan must be committed
    if ! git -C "$ROOT" cat-file -e "HEAD:$plan_rel" >/dev/null 2>&1; then
        continue
    fi

    # Check if slug is finished (has evidence of merge/deploy)
    is_finished=0
    for marker in merged.md deployment.md deployed.md release.md; do
        if [[ -f "$slug_dir/$marker" ]] && \
           git -C "$ROOT" cat-file -e "HEAD:.sdlc/$slug/$marker" >/dev/null 2>&1; then
            is_finished=1
            break
        fi
    done

    [[ "$is_finished" == 1 ]] && continue

    # This plan is active. Check if target path is listed.
    active_plan_found=1

    # Capture exit code without exiting script under set -e
    set +e
    path_in_plan "$plan_path" "$NORMALIZED"
    result=$?
    set -e

    if plan_is_fast_path "$plan_rel"; then
        fast_path_active=1
        [[ -z "$fast_path_slug" ]] && fast_path_slug="$slug"
        # A fast-path plan grants nothing on its own beyond ordinary files.
        [[ $result -eq 0 ]] && path_matches_plan=1
        continue
    fi

    if [[ $result -eq 0 ]]; then
        path_matches_plan=1
        ordinary_plan_covers_path=1
    elif [[ $result -eq 2 ]]; then
        # Plan exists but has no "Files that change" section, allow the write
        section_missing_in_active=1
        ordinary_plan_covers_path=1
    fi
done

# A sensitive path is closed while any fast-path change is in flight, unless a full
# plan — one that went through intent and spec — covers it. This runs before the
# exemption list because REVIEW.md is a .md file: exempting it first would let a
# fast-path change edit the very list that constrains it.
if [[ "$fast_path_active" == 1 ]] && is_sensitive "$NORMALIZED" \
   && [[ "$ordinary_plan_covers_path" == 0 ]]; then
    sanitized="$(sanitize_path "$NORMALIZED")"
    echo "AI SDLC artifact gate: blocked write to sensitive path $sanitized; .sdlc/$fast_path_slug/plan.md declares '## Fast path', which cannot cover a path listed in REVIEW.md 'Sensitive paths' or in the built-in governance list. Route this change through sdlc-plan." >&2
    exit 2
fi

# If not protected, check against exemption list
if ! is_protected "$NORMALIZED"; then
    if is_exempt "$NORMALIZED"; then
        exit 0
    fi
fi

# Allow if we found an active plan that lists this path
if [[ "$path_matches_plan" == 1 ]]; then
    exit 0
fi

# Allow if we found an active plan with no "Files that change" section
if [[ "$section_missing_in_active" == 1 ]]; then
    exit 0
fi

# Block if no active plan exists (gate re-arms when all are finished)
if [[ "$active_plan_found" == 0 ]]; then
    sanitized="$(sanitize_path "$NORMALIZED")"
    echo "AI SDLC artifact gate: blocked source-code write to $sanitized; create and commit .sdlc/<change>/plan.md first (or add .sdlc/OPTOUT)." >&2
    exit 2
fi

# Block: active plan exists but target path is not listed and section does exist
sanitized="$(sanitize_path "$NORMALIZED")"
echo "AI SDLC artifact gate: blocked source-code write to $sanitized; add the file to your active plan's '## Files that change' section and re-commit." >&2
exit 2
