# Azure Container Registry

## What it is

A private Docker / OCI registry — the storage layer that holds the application's container images. GitHub Actions builds an image on every merge to `main` and pushes it here; Azure Container Apps pulls from here on deploy and on scale-out. Same role as Docker Hub or GitHub Container Registry, but lives in our subscription and tenant.

Sits in the **app tier** of the architecture. Its lifecycle is tied to the deploy pipeline, not the database.

## Why we use it

- **Same trust boundary as the rest of Azure.** Image pulls go from Container Apps → ACR over Azure's network. Managed identity grants `AcrPull` via RBAC; no shared credentials.
- **No image leak risk.** Images are private by default and authenticate every pull via AAD — no anonymous reads, no admin user.
- **Cheaper than the alternatives at our scale.** Basic SKU is $5/month with 10 GB of storage. GHCR free tier is also fine, but adds a second tenant boundary to reason about (GitHub auth + Azure auth + cross-tenant token exchange).
- **Drop-in path to Private Endpoint later.** The `privatelink.azurecr.io` DNS zone is already deployed and linked to the VNet (Step 2.3). Whenever Premium becomes worth it, the PE is one resource away.

## How it's configured here

**Registry:** `crlifestackehyp` in `rg-lifestack-app-prod`, eastus2.

| Setting | Value | Why |
|---|---|---|
| SKU | `Basic` | $5/mo, 10 GB included. Sized for ~10 versions × ~400 MB. Premium would unlock PE/geo-replication/content-trust but pushes the v1 budget over $100/mo (ADR-0010). |
| Admin user | **disabled** | The admin user is a shared password that bypasses RBAC. Disabling it forces every pull/push through AAD identities. |
| Anonymous pull | **disabled** | Default, but explicit. Every pull requires an AAD token. |
| Public network access | `Enabled` | Basic doesn't support Private Endpoint. Authentication still gates access; the public endpoint is only reachable with a valid AAD token + `AcrPull` (or `AcrPush`) role. |
| Network rule bypass | `AzureServices` (default) | Lets Microsoft-trusted services (Container Apps, ACR Tasks) bypass network rules. On Basic this is mostly cosmetic — there are no network rules to bypass — but the default is correct. |
| Login server | `crlifestackehyp.azurecr.io` | Image references use this as the prefix: `crlifestackehyp.azurecr.io/lifestack-web:<tag>`. |

**Files:**

- `infra/modules/acr/` — reusable module (versions, variables, main, outputs).
- `infra/environments/prod/acr.tf` — module invocation.
- `infra/environments/prod/outputs.tf` — `acr_id`, `acr_name`, `acr_login_server`.

**Naming.** ACR names are 5–50 chars, **alphanumeric only** (no hyphens, no underscores), globally unique within `azurecr.io`. The pattern is `cr<project><random-suffix>` where the suffix comes from the env's shared `random_string.suffix`. This breaks the CAF `kind-app-env` convention because ACR's name rules don't allow hyphens — documented in `docs/services/terraform.md`.

## Mental model

- **A registry is a store for OCI artifacts**, addressed by `<registry-fqdn>/<repository>:<tag>`. The repository is created implicitly on first push; you don't pre-declare it.
- **Pulls and pushes are RBAC-controlled at the registry level**, not per-repository (Premium adds scope tokens for per-repo limits — not needed here).
- **The image is content-addressed.** A given image digest (`sha256:...`) is immutable; tags are mutable pointers to digests. Pulling by tag pulls whatever digest the tag currently points to; pulling by digest is reproducible.
- **The registry is stateful infrastructure.** Recreating it loses all images and all tag history. The Terraform-managed resource is the registry; the images inside are managed by CI/CD, not by Terraform.

## Alternatives considered

- **Docker Hub.** Free for public, paid for private. Different trust boundary (your Docker account, not your Azure tenant). Rate limits on anonymous pulls have been a recurring outage story. Not preferred for production workloads.
- **GitHub Container Registry (GHCR).** Free for public, free at small scale for private. Same trust boundary as the source code, which is convenient. Why not: introduces a second auth surface (GitHub PAT or workload identity → ACA), and crosses tenant boundaries (GitHub.com ↔ Azure). For a learning project oriented at Azure-native primitives, staying inside Azure is better.
- **ACR Standard or Premium.** Standard ($20/mo, 100 GB) buys more storage and throughput we don't need. Premium ($50/mo, 500 GB) buys Private Endpoint, geo-replication, content trust, scope tokens, and retention policy — all valuable, none required in v1. ADR-0010 captures the full trade.
- **Self-hosted registry on the same Container Apps env.** Possible, free in compute cost on top of what we already pay, but the operational burden of running your own registry (storage, backups, garbage collection, HA) is larger than the $5/month saved.

ADR-0010 captures the choice in formal form.

## Common operations

**Get the login server** (for `docker tag` / image references):
```bash
terraform -chdir=infra/environments/prod output -raw acr_login_server
```

**Login as the current AAD user** (for ad-hoc `docker push` / `docker pull` from the dev machine):
```bash
az acr login --name crlifestackehyp
```
Uses the current `az login` session — no admin password involved.

**List images in a repository:**
```bash
az acr repository show-tags --name crlifestackehyp --repository lifestack-web --orderby time_desc --output table
```

**Manually delete an old tag** (until automated cleanup is in place):
```bash
az acr repository delete --name crlifestackehyp --image lifestack-web:<old-tag>
```

**Grant a managed identity AcrPull** (run from the step that creates the consuming identity):
```bash
az role assignment create \
  --assignee <principal-id-of-MI> \
  --role AcrPull \
  --scope $(terraform -chdir=infra/environments/prod output -raw acr_id)
```
In Terraform, prefer `azurerm_role_assignment` — that's how Container Apps' identity will be wired in Step 2.6.

**Push an image from the CLI** (one-off, for testing):
```bash
docker tag lifestack-web:dev crlifestackehyp.azurecr.io/lifestack-web:dev
docker push crlifestackehyp.azurecr.io/lifestack-web:dev
```
Requires `az acr login` first; `docker push` reuses the AAD-issued token.

## Gotchas

- **No retention policy on Basic.** Premium-only feature. Untagged old images accumulate forever unless we prune them. With ~10 merges/month at ~400 MB per image we'd hit the 10 GB Basic cap in ~2.5 months. Mitigation: a scheduled GitHub Actions job that deletes manifests older than N days — written in Step 2.6 alongside the CI/CD pipeline.
- **No Private Endpoint on Basic.** Image pulls cross the public internet (auth-gated but not network-isolated). The `privatelink.azurecr.io` DNS zone provisioned in Step 2.3 is dormant — kept so the upgrade path is one resource.
- **No geo-replication on Basic.** Single-region registry. A region outage means we can't pull images for new deploys (but already-running containers keep running). Not relevant for v1's single-region footprint.
- **Tag `latest` is just a tag.** Pulling `latest` does not auto-mean the newest image — it means whatever was last pushed with that tag. Tag images deliberately, never rely on `latest` for deploys.
- **Manifest list / multi-arch images.** Building on macOS-arm64 by default produces an arm64 manifest, which won't run on x86_64 Container Apps. Build with `docker buildx build --platform linux/amd64` in CI; never trust a local-only image.
- **Empty registry is invisible until first push.** A freshly-provisioned ACR shows no repositories. `az acr repository list` returns `[]` until something has been pushed. Not a bug.

## Cost characteristics

| Component | Idle (v1) | What drives it |
|---|---|---|
| Basic SKU base | ~$5/mo | Fixed, regardless of storage used (up to 10 GB included). |
| Storage beyond 10 GB | n/a | Should not happen in v1 if pruning works. ~$0.10/GB/month over the included quota. |
| Outbound data transfer | $0 | Free within the same Azure region (ACR in eastus2, Container Apps in eastus2). |
| **Total v1** | **~$5/mo** | |

**Scale-up triggers (v2+):**
- Need for Private Endpoint (security audit, compliance) → Premium (~$50/mo).
- Multi-region deploy / DR → Premium for geo-replication.
- Signed images required → Premium for content trust.
- Storage approaching 10 GB even after pruning → Standard ($20/mo, 100 GB) is the cheap intermediate.

## Authoritative docs

- ACR overview & SKU comparison: <https://learn.microsoft.com/azure/container-registry/container-registry-skus>
- AAD authentication: <https://learn.microsoft.com/azure/container-registry/container-registry-authentication>
- Pulling from Container Apps with managed identity: <https://learn.microsoft.com/azure/container-apps/managed-identity-image-pull>
- Retention policy (Premium): <https://learn.microsoft.com/azure/container-registry/container-registry-retention-policy>
- Terraform `azurerm_container_registry`: <https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/container_registry>
