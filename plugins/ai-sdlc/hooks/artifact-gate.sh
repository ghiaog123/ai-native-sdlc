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

# If not protected, check against exemption list
if ! is_protected "$NORMALIZED"; then
    if is_exempt "$NORMALIZED"; then
        exit 0
    fi
fi

# At this point: either protected, or not exempt. Need a plan.
# Find all active plans (plan.md is committed, but slug is not finished).
shopt -s nullglob
active_plan_found=0
path_matches_plan=0
section_missing_in_active=0

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
    
    if [[ $result -eq 0 ]]; then
        # File found in plan
        path_matches_plan=1
        break
    elif [[ $result -eq 2 ]]; then
        # Plan exists but has no "Files that change" section, allow the write
        section_missing_in_active=1
        break
    fi
done

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
