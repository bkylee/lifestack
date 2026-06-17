#!/usr/bin/env bash
# Shared helpers for the prod Terraform stand-up / tear-down scripts.
# Sourced by standup.sh and teardown.sh — not meant to be run on its own.

set -euo pipefail

# Repo paths, resolved from this file's own location so the scripts work no
# matter which directory you invoke them from.
COMMON_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$COMMON_DIR/.." && pwd)"
PROD_DIR="$REPO_ROOT/infra/environments/prod"

# subscription_id is declared exactly once, in terraform.tfvars. Read it back
# from there so the GUID never lives in two places (drift would mean these
# commands silently target the wrong subscription).
SUBSCRIPTION_ID="$(grep -oP 'subscription_id\s*=\s*"\K[^"]+' "$PROD_DIR/terraform.tfvars")"

# require <cmd> — fail with a clear message if a needed tool is missing.
require() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "ERROR: '$1' not found on PATH." >&2
    exit 1
  }
}

preflight() {
  require terraform
  require az

  # The azurerm backend uses use_azuread_auth = true, and `az keyvault purge`
  # needs a logged-in CLI too. Fail early with a clear instruction instead of
  # letting terraform throw an opaque auth error halfway through a run.
  if ! az account show -o none 2>/dev/null; then
    echo "ERROR: not logged in to Azure. Run: az login" >&2
    exit 1
  fi

  # Pin the CLI to the lifestack subscription so a stray default subscription
  # can't aim these commands at the wrong tenant.
  az account set --subscription "$SUBSCRIPTION_ID"
  echo "Azure subscription: $(az account show --query name -o tsv) ($SUBSCRIPTION_ID)"
  echo
}
