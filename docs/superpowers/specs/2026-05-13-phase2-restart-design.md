# Phase 2 Restart — Design

*Date: 2026-05-13*

## Context

Phase 1 (app foundations) is complete and working. Phase 2 (infrastructure) is partway through: Terraform bootstrap, network module, Postgres Flex module, and ACR Basic module exist as code, but the work was driven by Claude with the user in a review seat. The user is restarting Phase 2 to shift the collaboration model: the user makes the configuration and decision calls; Claude scaffolds, mentors, and reviews. The goal is hands-on cloud-architect fluency, not just defensible reading comprehension.

Phase 1 is **not** being redone. Pedagogical value of redoing `create-next-app` and `prisma init` is low; the framework choices (Next.js, Prisma, Auth.js, Tailwind, shadcn) are preference-level and not architecturally load-bearing. The real architectural decisions (compute platform, edge, observability stack, DB hosting model, auth model) are gated on Phase 2 ADRs — those get genuinely made by the user as each module is built.

## Goals

- Bridge cert-level Azure knowledge into production-fluent decision-making across the full stack: network, identity, secrets, compute, data, observability, edge.
- Produce a prod environment that genuinely runs end-to-end in Azure.
- Produce documentation (service docs, ADRs, changelog entries) **authored primarily by the user**, edited by Claude. The interview-defensibility comes from having written it, not from having read it.
- Establish multi-environment IaC scaffolding without paying for multiple environments.

## Non-goals

- Redoing Phase 1 app code.
- Deploying dev or staging environments in v1. Scaffold only.
- Blob Storage (deferred — Phase 11 in CLAUDE.md).
- CI/CD pipelines (separate from this plan).
- Actual app deployment beyond a `/healthz` smoke test (Phase 3+).

## What stays (untouched)

- All Phase 1 app code (Next.js, Prisma, Auth.js, auth-aware home page).
- `docker-compose.yml` for local dev.
- `CLAUDE.md`.
- `docs/changelog.md` — appended to, never rewritten.
- `docs/architecture.md` — updated as state changes.
- Existing ADRs (0001, 0002, 0007, 0009, 0010). Note: 0009 (managed Postgres) and 0010 (ACR Basic) are tied to modules being redone — they may be revisited and superseded during Modules 5 and 6. Per CLAUDE.md, superseded ADRs are never deleted; a new ADR replaces them and the old one is marked Superseded.
- `docs/services/{nextjs,prisma,nextauth,tailwind-shadcn,terraform}.md`.
- Terraform state backend storage account in Azure (if it exists).
- `infra/environments/prod/{backend,versions}.tf`.

## What gets archived

Moved to `infra/.reference/` and `docs/.reference/` for in-place comparison. Git history retains everything regardless.

- `infra/modules/{network,postgres,acr}/`
- `infra/environments/prod/{network,postgres,acr,resource_groups,budget,random,locals,main}.tf`
- `docs/services/azure-{network,postgres-flexible,container-registry}.md`

## What gets torn down in Azure

To be determined by Module 0 audit. Anything `terraform apply`-ed beyond the state backend gets `terraform destroy`-ed *before* its `.tf` files are archived (otherwise resources orphan from state). The state backend storage account itself stays — it's plumbing, not learning.

## New working cadence (per module)

1. Claude sends: scaffolded `.tf` file with `[D#]` decision markers; variables/outputs skeleton; mentor message with — per decision — the textbook line, production reality, recommended pick with reasoning, and what to do.
2. User: fills in values, asks questions when unsure.
3. Claude reviews: sign off / push back / flag what's missing.
4. User: `terraform fmt`, `terraform plan`, pastes output.
5. Both read the plan together; user articulates what each resource will create.
6. User: `terraform apply`.
7. User: drafts `docs/services/<thing>.md` and a `docs/changelog.md` entry.
8. Claude edits the docs line-by-line, with reasoning for edits.
9. Commit.
10. If an architectural decision was made: user drafts the ADR, Claude edits.

Docs ownership flips: **user writes first drafts, Claude edits.** Interview-defensibility lives in having written it.

## Multi-environment strategy

Scaffold for dev/staging/prod from Module 1; deploy only prod in v1. Each environment is a sibling directory under `infra/environments/` with its own state, its own `terraform.tfvars`, and the same set of module calls. Environments differ only by variable values (SKU tier, retention days, replica counts, etc.) and the env tag on every resource.

**Rationale:** the architectural muscle of multi-env IaC (separate state, parameterized modules, env-tagging discipline) is built once, up front. The operational cost of running multiple environments is deferred until there's a real trigger. This matches CLAUDE.md's existing stance and is captured in ADR-0005.

**Triggers to actually deploy dev:**
- A destructive migration we want to validate against a non-prod copy of data.
- A network refactor that could partition prod if misconfigured.
- A compute-platform re-evaluation (e.g., AKS migration POC).

**Why not permanent dev:** ~$30–50/mo recurring cost, will drift from prod without active discipline, low marginal learning value once the scaffold pattern is internalized.

**Why not always-on staging:** modern small-team practice has largely replaced permanent staging with feature flags, per-PR ephemeral previews, and blue/green deploys. The defensible architect answer is environment strategy as a function of org size, change risk, traffic, and compliance — not "always three environments."

## Module sequence

| # | Module | Why this order |
|---|---|---|
| 0 | **Live Azure audit** | Determine what's actually applied today before tearing anything down. |
| 1 | **Resource groups + naming/tagging convention + multi-env scaffolding** | No dependencies. Establishes conventions every later module reuses. Low-stakes cadence warm-up. ADR-0005 (multi-env strategy) written here. |
| 2 | **Network** (VNet, subnets, NSGs, private DNS zones) | No external dependencies. Biggest single concept-to-production piece. Everything else lands inside it. |
| 3 | **Key Vault** | Needs RG + (optionally) network for private access. Goes in early so secrets have a home before anything wants to read them. |
| 4 | **Log Analytics + Application Insights** | Needs RG. Exists before compute so logs land somewhere from day one. |
| 5 | **ACR** (Container Registry) | Needs RG. Enables image push. |
| 6 | **Postgres Flex (with private endpoint)** | Needs network + KV. Hardest networking piece — private endpoint + private DNS resolution. |
| 7 | **Container Apps Environment + Container App + Managed Identity** | Needs all of the above. The keystone — managed identity binds it together: pulls from ACR, reads from KV, ships logs to LA, talks to Postgres over private endpoint. ADR-0008 (Container Apps choice) written here. |
| 8 | **Front Door** | Last. Points at CA. ADR-0004 (Front Door + skip App Gateway) written here. |
| 9 | **End-to-end smoke test** | Dummy `/healthz` page reachable through Front Door → Container App → reads a Key Vault secret → talks to Postgres. The moment of truth. |

## Definition of done for Phase 2

- Prod environment running end-to-end. Dummy `/healthz` returns 200 through Front Door, with KV secret read and Postgres query in the path.
- Nine `docs/services/azure-*.md` files authored primarily by user, edited by Claude.
- ADRs for genuine decisions: minimally 0004 (edge), 0005 (env strategy — confirmed), 0008 (compute platform). Possibly more depending on what surfaces.
- One `docs/changelog.md` entry per module, capturing non-obvious decisions and verification.
- `docs/architecture.md` updated to reflect current state.
- User can defend every resource in the architecture diagram without notes.

## Rough scope estimate

Nine modules + smoke test, ~1–3 working sessions per module depending on size. Network and Container Apps are the long ones; resource groups and ACR are quick. Order-of-magnitude: 15–25 sessions.

## Risks

- **Sunk-cost drag.** Tempting to "just use" the archived modules instead of re-deriving. Mitigation: archive directory, not active reference; user makes decisions fresh and *then* compares.
- **Cost overrun.** Postgres Flex (~$15/mo even idle) and Front Door (~$35/mo base) are the largest line items. Mitigation: $100/mo budget alert already wired; user audits monthly during Phase 2.
- **Decision fatigue.** Some modules carry many small decisions (KV alone has SKU, retention, RBAC, network access). Mitigation: Claude flags which decisions are load-bearing vs cosmetic; user spends their decision-effort on the architectural ones.
- **Auth.js v5 + Next.js 16 compatibility drift.** Documented in changelog Step 1; not blocking Phase 2 but should be tracked.
