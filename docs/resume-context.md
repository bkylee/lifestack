# Lifestack — Context for Resume Work

> A one-page distillation of what this project is, what's built, and what it demonstrates — sized for resume framing and architect-interview prep. Pair this with my resume when working with Claude in the desktop app.

## Elevator pitch

Lifestack is an end-to-end web platform deployed on Azure, provisioned with Terraform, and operated with production-grade security and observability posture. The product itself is a multi-hobby review and collection platform — "Letterboxd, but unified across every hobby a person has." The product is real and intended to ship publicly, but its **primary purpose for me is as a capstone for cloud-architecture learning**.

## Why this project exists

I come from an IT infrastructure background — hardware design, deployment, support, IT admin — with study/cert-level knowledge across Azure services, Terraform, Docker, networking, security posture, and observability patterns. My career target is a **cloud architect / IT infrastructure architect** role.

The gap I'm closing: I can read an architecture diagram and explain each box, but I haven't designed and operated a full stack end-to-end. Lifestack is the deliberate bridge between "I know what a Private Endpoint is" and "I've configured one in production and understand the gotchas."

Trade-off I'm explicit about: **understanding > shipping**. When choices arise between "build faster" and "learn deeper," I default to deeper. The product is the vehicle; the architecture is the point.

## Tech stack

**Infrastructure (Azure):**
- Container Apps (scale-to-zero) for app hosting
- Azure Container Registry
- Front Door Standard (WAF, CDN, TLS termination)
- Postgres Flexible Server with private endpoint; `pgvector` extension installed for future use
- Blob Storage (separate containers per image size)
- Key Vault, accessed via Container Apps managed identity — no secrets in code or env files
- Application Insights + Log Analytics (single workspace, unified sink)

**IaC and CI/CD:**
- Terraform with reusable modules; remote state in Azure Storage backend
- GitHub Actions (separate pipelines for infra and app)
- Single environment deployed (`prod`); `dev` and `staging` structured but not provisioned

**Application:**
- Next.js 16 (App Router, server components by default)
- TypeScript strict mode
- Prisma ORM against managed Postgres
- NextAuth (Auth.js v5), Google + GitHub OAuth
- Tailwind CSS + shadcn/ui, Lucide icons
- Sharp for image processing (resize, optimize, EXIF strip)
- Resend for transactional email

## Architectural patterns demonstrated

- **Tier-split resource groups** (`network`, `data`, `app`, `observability`) for RBAC scoping and per-tier cost attribution — mirrors how real orgs assign team access.
- **Private endpoints + private DNS zones** for database isolation; Postgres is not publicly reachable.
- **Managed identity → Key Vault** for secret retrieval at app startup; secrets never live in code, env files, or container images.
- **Defense in depth**: Front Door WAF → Container Apps (no public DB credentials) → private Postgres behind a private endpoint.
- **IaC-first**: every Azure resource is Terraform-managed, with one bootstrap exception (the Terraform state storage account itself, created by hand before Terraform existed).
- **Unified observability**: Front Door, Container Apps, Postgres, and Blob Storage all ship logs into a single Log Analytics workspace; Application Insights handles distributed tracing.
- **Documentation as a first-class deliverable**: service reference docs, ADRs, operational runbooks, and a narrative build changelog live in the repo and update with each change.

## Current state — honest

**Live status lives in `CLAUDE.md` → "Current phase".** That section is the single source of truth for which Phase 2 module is built, applied, or in progress — it updates as modules complete, so this doc doesn't duplicate (and drift from) it. Read it there; the framing below is what stays true regardless of which module is active.

The work is sequenced as numbered Phase 2 modules, each deployed by hand and documented before moving on:

1. Resource groups + naming/tagging + multi-env scaffolding
2. Network — VNet, subnets, NSGs, private DNS zones
3. Key Vault (first private endpoint)
4. Log Analytics + Application Insights
5. Container Registry
6. Postgres Flexible Server (private endpoint)
7. Container Apps + managed identity
8. Front Door
9. End-to-end smoke test

The application layer (Next.js / Prisma / the product itself) is Phase 3+ and deliberately deferred until the infrastructure is in place.

**Important framing context**: Phase 2 was deliberately torn down and restarted on 2026-05-13. The first-pass infrastructure (29 Azure resources) had been built too quickly with too much automation, and I lost the learning that was the point of the project. The restart uses a hands-on cadence — I drive every configuration decision myself, with Claude scaffolding and mentoring — so the resulting docs and decisions are ones I personally made and can defend.

## Decisions I can defend in interviews

Each of these has reasoning, alternatives considered, and trade-offs I can articulate from doing the work — not just from reading about it:

- **Container Apps** over App Service or AKS — scale-to-zero, no orchestration overhead at v1 scale
- **Front Door direct to Container Apps**, no App Gateway in v1 — with documented trigger to add one later
- **Azure-managed Postgres** over self-hosted — operational-burden vs. control trade-off
- **NextAuth** over Clerk / Auth0 — cost, vendor lock-in, control
- **Skip Redis in v1** — Postgres handles sessions, caching, and queues at this scale
- **Single `prod` environment in v1**, structured for dev/staging — trigger to add: a migration scary enough to warrant a non-prod test
- **EAV vs JSONB** for hobby-specific product attributes — relational query trade-offs
- **Resource group split by tier** vs. flat single RG — latent RBAC benefit, active cost-attribution benefit
- **Deliberate Phase 2 teardown and restart** — recognizing when speed had stolen the learning, and choosing rigor over progress

Each non-obvious decision is captured as an ADR in `docs/decisions/`.

## Deferred / future scope (decisions, not oversights)

Each item below has a documented trigger for revisiting:

- Redis caching layer
- Azure App Gateway (path-based routing, mTLS to backend)
- Multi-environment deployment (dev, staging)
- Dedicated search infrastructure (Meilisearch / Elastic)
- Native mobile apps
- Payments / paid tier
- Recommendation engine and taste-similarity features (v3)

## Where to find more

If the desktop app needs deeper context on a specific area, ask me to upload:

- `CLAUDE.md` — full project orientation (conventions, calibration, work style)
- `docs/superpowers/specs/2026-05-13-phase2-restart-design.md` — Phase 2 architectural source-of-truth
- `docs/changelog.md` — narrative record of what's been built and why
- `docs/services/azure-<name>.md` — per-service reference docs (rationale, config, gotchas, cost)
- `docs/decisions/ADR-NNNN-*.md` — non-obvious architectural decisions
- `docs/mentor/m{module}-s{step}-*.md` — per-step mentor briefings with decision points

---

*Last updated: 2026-06-14*
