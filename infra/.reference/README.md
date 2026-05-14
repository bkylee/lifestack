# `.reference/` — archived Phase 2 (first pass)

This directory holds the original Phase 2 infrastructure code, written by Claude before the project pivoted to a hands-on collaboration model. The corresponding Azure resources were destroyed on 2026-05-13 (`terraform destroy`, 29 resources). The files were moved here with `git mv`, so `git blame` and `git log --follow` continue to work.

## What's here

- `modules/network/` — VNet, 3 subnets (aca, pg, pe), 3 NSGs, 4 private DNS zones (postgres, blob, kv, acr) + VNet links.
- `modules/postgres/` — Postgres Flex Burstable B1ms, eastus2, with private endpoint wiring.
- `modules/acr/` — ACR Basic SKU.
- `environments/prod/` — the wiring that called those modules: locals, variables, tfvars, resource groups, budget, outputs, provider config, randoms.

## What's not here

The pieces still in active use stayed in `infra/environments/prod/`:
- `backend.tf` — state backend config (unchanged).
- `versions.tf` — provider version pins (unchanged).

The state backend storage account (`stlifestack9k3l` in `rg-lifestack-tfstate`) was never destroyed — it survives the reset.

## How to use it

When you're working through the Phase 2 redo and want to see how something was solved last time:

```bash
# diff your current take against the archived version
diff infra/modules/network/main.tf infra/.reference/modules/network/main.tf

# read the archived doc alongside the new one
less docs/.reference/services/azure-network.md
```

Treat it as **reference only**. Don't copy verbatim — the point of the redo is to make the decisions yourself.

## When this archive can be deleted

After Phase 2 redo is complete and the corresponding service docs and ADRs are written, the archive is just historical. It can be deleted (git history retains everything) or kept indefinitely — disk cost is trivial.
