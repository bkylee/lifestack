#!/usr/bin/env bash
# standup.sh — bring the prod environment up from nothing.
#
# Runs `terraform init` (idempotent) then `terraform apply` against
# infra/environments/prod. Pair with teardown.sh: stand up to work, tear down
# when you stop, so the fixed-cost resources that can't scale to zero
# (Front Door, ACR, private endpoints, Postgres storage) only bill while you're
# actually using the stack. See docs/operations/cost.md.
#
# Usage: scripts/standup.sh [-y]
#   -y, --yes   skip the `terraform apply` confirmation prompt

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/_tf_common.sh
source "$SCRIPT_DIR/_tf_common.sh"

APPLY_ARGS=()
case "${1:-}" in
  -y | --yes) APPLY_ARGS+=(-auto-approve) ;;
  "") ;;
  *)
    echo "Unknown argument: $1" >&2
    exit 1
    ;;
esac

preflight

# init is safe to re-run; it's needed after a fresh clone or if .terraform was
# cleared, and a no-op otherwise.
terraform -chdir="$PROD_DIR" init -input=false

terraform -chdir="$PROD_DIR" apply "${APPLY_ARGS[@]}"

echo
echo "Stack is up — these resources are now billing."
echo "Run scripts/teardown.sh when you're done for the day/week."
