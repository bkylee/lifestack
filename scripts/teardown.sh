#!/usr/bin/env bash
# teardown.sh — destroy the prod environment so it stops billing.
#
# Runs `terraform destroy` against infra/environments/prod, then purges any
# soft-deleted Key Vaults left behind. With purge_soft_delete_on_destroy = false
# (infra/environments/prod/main.tf) a destroyed Key Vault is only *soft*-deleted:
# it keeps its globally-unique name reserved for the retention window (7 days),
# which would block standup.sh from recreating it under the same name. Purging
# releases the name so the destroy -> standup cycle round-trips cleanly.
#
# Pair with standup.sh. See docs/operations/cost.md.
#
# Usage: scripts/teardown.sh [-y]
#   -y, --yes   skip confirmation prompts (terraform destroy + vault purge)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/_tf_common.sh
source "$SCRIPT_DIR/_tf_common.sh"

ASSUME_YES=false
case "${1:-}" in
  -y | --yes) ASSUME_YES=true ;;
  "") ;;
  *)
    echo "Unknown argument: $1" >&2
    exit 1
    ;;
esac

preflight

DESTROY_ARGS=()
$ASSUME_YES && DESTROY_ARGS+=(-auto-approve)

terraform -chdir="$PROD_DIR" destroy "${DESTROY_ARGS[@]}"

# After destroy, release any soft-deleted Key Vault names so they don't block
# the next standup. Scoped to the subscription already pinned in preflight.
# Today (pre-Module 3) there are no vaults, so this cleanly reports "None found".
echo
echo "Checking for soft-deleted Key Vaults to purge..."
DELETED_NAMES=()
DELETED_LOCS=()
while IFS=$'\t' read -r name loc; do
  [ -z "$name" ] && continue
  DELETED_NAMES+=("$name")
  DELETED_LOCS+=("$loc")
done < <(az keyvault list-deleted --query "[].[name, properties.location]" -o tsv)

if [ "${#DELETED_NAMES[@]}" -eq 0 ]; then
  echo "None found."
else
  echo "Soft-deleted vaults still holding their globally-unique names:"
  for i in "${!DELETED_NAMES[@]}"; do
    printf '  - %s (%s)\n' "${DELETED_NAMES[$i]}" "${DELETED_LOCS[$i]}"
  done
  if ! $ASSUME_YES; then
    read -rp "Purge these permanently so the names free up? [y/N] " reply
    [[ "$reply" =~ ^[Yy]$ ]] || {
      echo "Skipped. Names stay reserved until Azure auto-purges them."
      exit 0
    }
  fi
  for i in "${!DELETED_NAMES[@]}"; do
    echo "Purging ${DELETED_NAMES[$i]}..."
    az keyvault purge --name "${DELETED_NAMES[$i]}" --location "${DELETED_LOCS[$i]}"
  done
fi

echo
echo "Teardown complete. The prod stack is gone; only the tfstate storage account remains (pennies)."
