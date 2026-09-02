#!/usr/bin/env bash
set -euo pipefail

# AI-SDLC Production Guard: Defense in Depth, Not a Security Boundary
# ====================================================================
# This hook catches common destructive patterns (terraform apply, kubectl delete -n prod, etc.)
# to block accidental production changes during AI-assisted development.
#
# WHAT THIS IS:
# - A safety net for the common destructive verb + production signal patterns.
# - Catches typical typos, missed flags, and accidental context switches.
#
# WHAT THIS IS NOT:
# - A security boundary. A determined caller can always spell a command to evade regex.
# - A substitute for IAM, deploy approvals, and branch protection.
# - A replacement for server-side deploy controls.
#
# REAL CONTROLS: IAM roles, RBAC, deploy workflow approvals, branch protection,
# read-only production credentials, infrastructure as code reviews, observability.
#
# Opt-in per repository (like all AI-SDLC hooks). Set AI_SDLC_ALLOW_PROD=1 only after
# explicit human authorization to bypass.

ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
if [[ ! -d "$ROOT/.sdlc" ]] || [[ -e "$ROOT/.sdlc/OPTOUT" ]]; then
  exit 0
fi

if [[ "${AI_SDLC_ALLOW_PROD:-}" == "1" ]]; then
  exit 0
fi

# Extract command from tool input JSON.
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

# ============================================================================
# Production Detection Helpers
# ============================================================================

# Detect production for a kubectl invocation.
#
# A prod signal is not always a flag. `kubectl delete ns production` names the namespace
# positionally, and that is exactly the command worth stopping, so scan the whole
# argument string for a production-shaped token as well as the explicit flags.
is_kubectl_production() {
  local cmd="$1"

  # Any production-shaped word anywhere in the arguments, flag or positional.
  # Tokenised rather than pattern-matched on purpose: a bracket expression that has to
  # cover quotes, slashes and '=' is easy to get subtly wrong, and a regex that silently
  # matches the empty string blocks every command instead of the dangerous ones.
  local token
  for token in ${cmd//[\/=:,\"\']/ }; do
    case "$token" in
      prod|production|prd|live) return 0 ;;
    esac
  done

  # Check for explicit production signals in flags (both long and short forms).
  if [[ "$cmd" =~ --context[[:space:]]*[^[:space:]]*prod ]] || \
     [[ "$cmd" =~ --kubeconfig[[:space:]]*[^[:space:]]*prod ]] || \
     [[ "$cmd" =~ --namespace[[:space:]]*prod ]] || \
     [[ "$cmd" =~ --namespace[[:space:]]*production ]] || \
     [[ "$cmd" =~ --namespace[[:space:]]*live ]] || \
     [[ "$cmd" =~ --namespace[[:space:]]*prd ]] || \
     [[ "$cmd" =~ -n[[:space:]]+(production|prod|live|prd) ]]; then
    return 0
  fi
  
  # An explicit --context/--kubeconfig naming a non-production cluster wins over whatever
  # the machine happens to be pointed at. Explicit beats implicit, and without this a
  # developer whose default context is production cannot address any other cluster.
  if [[ "$cmd" =~ (--context|--kubeconfig)([[:space:]]+|=)([^[:space:]]+) ]]; then
    return 1
  fi

  # If no explicit flag, check the currently selected context.
  # Timeout fast (100ms), discard stderr, graceful fail if kubectl is absent.
  if command -v kubectl &>/dev/null; then
    local current_context
    # `timeout` is absent on macOS, where this silently disabled the whole fallback.
    if command -v timeout >/dev/null 2>&1; then
      current_context=$(timeout 2 kubectl config current-context 2>/dev/null || echo "")
    else
      current_context=$(kubectl config current-context 2>/dev/null || echo "")
    fi
    if [[ -n "$current_context" && "$current_context" =~ prod|production|live|prd ]]; then
      return 0
    fi
  fi
  
  return 1
}

# Detect production from AWS flags and resource names.
is_aws_production() {
  local cmd="$1"
  
  if [[ "$cmd" =~ --profile[[:space:]]*[^[:space:]]*prod ]] || \
     [[ "$cmd" =~ --region[[:space:]]*[^[:space:]]*prod ]] || \
     [[ "$cmd" =~ s3://prod ]] || \
     [[ "$cmd" =~ s3://production ]]; then
    return 0
  fi
  
  return 1
}

# Detect production from gcloud project/zone.
is_gcloud_production() {
  local cmd="$1"
  
  if [[ "$cmd" =~ --project[[:space:]]*[^[:space:]]*prod ]] || \
     [[ "$cmd" =~ --project[[:space:]]*[^[:space:]]*production ]]; then
    return 0
  fi
  
  return 1
}

# Detect production from Azure subscription/resource group.
is_azure_production() {
  local cmd="$1"
  
  if [[ "$cmd" =~ --subscription[[:space:]]*[^[:space:]]*prod ]] || \
     [[ "$cmd" =~ --resource-group[[:space:]]*[^[:space:]]*prod ]]; then
    return 0
  fi
  
  return 1
}

# Detect if a database connection string or env flag targets production.
is_db_production() {
  local cmd="$1"
  
  if [[ "$cmd" =~ --env[[:space:]]*prod ]] || \
     [[ "$cmd" =~ DATABASE_URL.*prod ]] || \
     [[ "$cmd" =~ DATABASE_URL.*production ]] || \
     [[ "$cmd" =~ postgres://.*prod ]] || \
     [[ "$cmd" =~ mysql://.*prod ]]; then
    return 0
  fi
  
  return 1
}

# Skip if this is a read-only or plan-only operation.
is_readonly_operation() {
  local cmd="$1"
  
  # Terraform reads and plans.
  if [[ "$cmd" =~ terraform[[:space:]]+(plan|show|refresh|state[[:space:]]+(list|show)) ]]; then
    return 0
  fi
  
  # kubectl reads (get, describe, logs, top, etc.) and dry-run.
  if [[ "$cmd" =~ kubectl[[:space:]]+(get|describe|logs|top|version) ]] || \
     [[ "$cmd" =~ --dry-run ]]; then
    return 0
  fi
  
  # Helm show and get.
  if [[ "$cmd" =~ helm[[:space:]]+(show|get) ]]; then
    return 0
  fi
  
  # Generic read-only tools (grep, cat, echo, comments).
  if [[ "$cmd" =~ ^[[:space:]]*(grep|rg|ack|cat|echo|less|more|head|tail) ]] || \
     [[ "$cmd" =~ ^# ]]; then
    return 0
  fi
  
  # Help or plan-only flags (not -n, which is overloaded in many commands).
  if [[ "$cmd" =~ (--help|-h|--plan|--plan-only|--dry-run) ]]; then
    return 0
  fi
  
  return 1
}

# ============================================================================
# Check Commands Against Rules
# ============================================================================

BLOCKED_RULE=""
BLOCKED_VERB=""

# Fast-path: skip if obviously read-only.
if is_readonly_operation "$COMMAND"; then
  exit 0
fi

# kubectl mutating verbs. One loop, not eight limbs: adding a verb is one word.
for kverb in apply delete replace patch scale rollout drain cordon uninstall; do
  if [[ "$COMMAND" =~ kubectl([[:space:]]|.*[[:space:]])"$kverb"([[:space:]]|$) ]] \
     && is_kubectl_production "$COMMAND"; then
    BLOCKED_RULE="kubectl $kverb against a production target"
    BLOCKED_VERB="$kverb"
    break
  fi
done

if [[ -n "${BLOCKED_RULE:-}" ]]; then
  :
# Terraform: destructive in any position
elif [[ "$COMMAND" =~ terraform.*apply ]]; then
  BLOCKED_RULE="terraform apply"
  BLOCKED_VERB="apply"
elif [[ "$COMMAND" =~ terraform.*destroy ]]; then
  BLOCKED_RULE="terraform destroy"
  BLOCKED_VERB="destroy"

# Helm: destructive operations
elif [[ "$COMMAND" =~ helm.*upgrade ]]; then
  BLOCKED_RULE="helm upgrade"
  BLOCKED_VERB="upgrade"
elif [[ "$COMMAND" =~ helm.*install ]]; then
  BLOCKED_RULE="helm install"
  BLOCKED_VERB="install"
elif [[ "$COMMAND" =~ helm.*uninstall ]]; then
  BLOCKED_RULE="helm uninstall"
  BLOCKED_VERB="uninstall"
elif [[ "$COMMAND" =~ helm.*rollback ]]; then
  BLOCKED_RULE="helm rollback"
  BLOCKED_VERB="rollback"

# AWS: requires production signal
elif [[ "$COMMAND" =~ aws[[:space:]]+s3[^a-z]*(rm|rb) ]] && is_aws_production "$COMMAND"; then
  BLOCKED_RULE="AWS S3 destructive operation on production bucket"
  BLOCKED_VERB="rm/rb"
elif [[ "$COMMAND" =~ aws.*delete ]] && is_aws_production "$COMMAND"; then
  BLOCKED_RULE="AWS delete on production"
  BLOCKED_VERB="delete"

# GCP: requires production signal
elif [[ "$COMMAND" =~ gcloud.*delete ]] && is_gcloud_production "$COMMAND"; then
  BLOCKED_RULE="gcloud delete on production"
  BLOCKED_VERB="delete"

# Azure: requires production signal
elif [[ "$COMMAND" =~ az.*delete ]] && is_azure_production "$COMMAND"; then
  BLOCKED_RULE="Azure delete on production"
  BLOCKED_VERB="delete"

# GitHub: release creation and deploy workflow triggers
elif [[ "$COMMAND" =~ gh[[:space:]]+release[[:space:]]+create ]]; then
  BLOCKED_RULE="gh release create"
  BLOCKED_VERB="create"
elif [[ "$COMMAND" =~ gh[[:space:]]+workflow[[:space:]]+run.*(deploy|release) ]]; then
  BLOCKED_RULE="gh workflow run targeting deploy or release"
  BLOCKED_VERB="run"

# Registry and publication
elif [[ "$COMMAND" =~ npm[[:space:]]+publish ]]; then
  BLOCKED_RULE="npm publish"
  BLOCKED_VERB="publish"
elif [[ "$COMMAND" =~ docker[[:space:]]+push.*prod ]]; then
  BLOCKED_RULE="docker push to production registry"
  BLOCKED_VERB="push"

# Deploy wrappers: these are common and dangerous
elif [[ "$COMMAND" =~ make[[:space:]]+deploy ]]; then
  BLOCKED_RULE="make deploy*"
  BLOCKED_VERB="deploy"
elif [[ "$COMMAND" =~ npm[[:space:]]+run[[:space:]]+[^[:space:]]*(deploy|release|publish) ]]; then
  BLOCKED_RULE="npm/yarn/pnpm run *deploy* or *release*"
  BLOCKED_VERB="deploy/release"
elif [[ "$COMMAND" =~ \./deploy.*\.sh|bash[[:space:]]+deploy.*\.sh ]]; then
  BLOCKED_RULE="./deploy*.sh or bash deploy*.sh"
  BLOCKED_VERB="deploy"
elif [[ "$COMMAND" =~ flyctl[[:space:]]+deploy|fly[[:space:]]+deploy ]]; then
  BLOCKED_RULE="flyctl or fly deploy"
  BLOCKED_VERB="deploy"
elif [[ "$COMMAND" =~ vercel.*--prod ]]; then
  BLOCKED_RULE="vercel --prod"
  BLOCKED_VERB="deploy"
elif [[ "$COMMAND" =~ netlify[[:space:]]+deploy[[:space:]]+--prod ]]; then
  BLOCKED_RULE="netlify deploy --prod"
  BLOCKED_VERB="deploy"
elif [[ "$COMMAND" =~ serverless[[:space:]]+deploy ]]; then
  BLOCKED_RULE="serverless deploy"
  BLOCKED_VERB="deploy"

# Infrastructure as code and orchestration
elif [[ "$COMMAND" =~ ansible-playbook.*(prod|production) ]]; then
  BLOCKED_RULE="ansible-playbook targeting production"
  BLOCKED_VERB="deploy"

# Database: requires production detection
elif [[ "$COMMAND" =~ (migrate|migration).*(prod|production)|psql.*prod.*migrate|mysql.*prod.*migrate ]] && is_db_production "$COMMAND"; then
  BLOCKED_RULE="database migration against production"
  BLOCKED_VERB="migrate"
elif [[ "$COMMAND" =~ (DROP[[:space:]]+TABLE|TRUNCATE|DELETE[[:space:]]+FROM) ]] && is_db_production "$COMMAND"; then
  BLOCKED_RULE="destructive SQL (DROP/TRUNCATE/DELETE) against production"
  BLOCKED_VERB="destroy"
fi

if [[ -n "$BLOCKED_RULE" ]]; then
  {
    echo "AI-SDLC production guard: blocked '$BLOCKED_VERB' (rule: $BLOCKED_RULE)"
    echo ""
    echo "Explicit human authorization is required. Set AI_SDLC_ALLOW_PROD=1 only after:"
    echo "  - Human approval documented in your change request or ticket"
    echo "  - Verification that you are targeting the correct environment"
    echo "  - Confirmation that this is not a typo or accidental context switch"
    echo ""
    echo "Real controls: IAM roles, RBAC, deploy approvals, branch protection."
  } >&2
  exit 2
fi

exit 0
