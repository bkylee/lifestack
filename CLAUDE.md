# CLAUDE.md

> Project context for Claude Code. Place at repo root. Treat as a living document — update whenever a decision or convention is established that future sessions should know.

---

## Project

A person-first, multi-hobby review and collection platform. Users track items they own / used to own / want, write multi-axis reviews scored on per-hobby rating dimensions, follow other users, and (in v3) discover items via taste-similar peers across hobbies they don't have yet.

Think Letterboxd, but unified across *all* a person's hobbies in one profile.

**Status:** MVP v1, single launch hobby, web-first.

**Working name:** TBD — replace this line when chosen.

**Launch hobby:** TBD — pick the one I personally care about. Side-project motivation lives or dies on personal interest. Replace this line when chosen.

---

## Current phase

**Phase 2 — Infrastructure restart (as of 2026-05-13).** Phase 1 (foundations) complete. Phase 2 first pass was Claude-driven; deliberately torn down and restarted with hands-on cadence (see "Hands-on cadence" under "How to work with me"). 29 Phase 2 Azure resources destroyed; old code archived to `infra/.reference/` and `docs/.reference/`. State backend storage account `stlifestack9k3l` in `rg-lifestack-tfstate` survives.

**Module sequence:**

1. Resource groups + naming/tagging + multi-env scaffolding (ADR-0005) ← **Complete** (2026-06-03)
2. Network (VNet, subnets, NSGs, private DNS zones) ← **In progress** — Step 1 (mentor file written, Brian writing `network.tf`)
3. Key Vault
4. Log Analytics + Application Insights
5. Container Registry
6. Postgres Flexible Server (with private endpoint)
7. Container Apps + managed identity (ADR-0008)
8. Front Door (ADR-0004)
9. End-to-end smoke test

Blob storage, CI/CD, app deploy deferred to Phase 3+.

- Source-of-truth spec: `docs/superpowers/specs/2026-05-13-phase2-restart-design.md`
- Mentor messages: `docs/mentor/`

Update this section as modules complete.

---

## Who I am

IT infrastructure professional. Day job is operational — hardware design, deployment, support, IT admin. Career goal: cloud architect / IT infra architect.

## WSL-specific notes

- Project lives in WSL filesystem (`~/projects/`), not on Windows mount (`/mnt/c/`).
- `code .` from WSL terminal opens VS Code in WSL-attached mode (correct).
- Docker Desktop on Windows with WSL2 integration enabled — `docker` CLI works directly from WSL terminal.
- Line endings: enforced LF via `.gitattributes`. Don't change.
- If file watchers misbehave or things get weird: `wsl --shutdown` from PowerShell, reopen.

### Knowledge calibration (read this carefully)

I have **study-level and cert-level knowledge** across:
- Azure services
- Terraform
- Docker
- Networking (VNets, NSGs, Private Endpoints, DNS)
- Security posture (managed identity, Key Vault, defense-in-depth)
- Observability patterns
- Deployment pipelines
- Operational discipline (ITSM, CMDB)

What this means: I know the vocabulary, can read a diagram or config and follow it, and have done basic hands-on work. **What I don't have is real working experience designing and operating a full architectural stack end-to-end.** This project is the bridge between "I know what a Private Endpoint is" and "I've configured one in production and understand the gotchas."

For modern web app development (TypeScript, React, Next.js, Prisma), my exposure is roughly The Odin Project level. Comfortable with HTML/CSS/basic JS. Not production-grade with the modern stack.

So: don't explain *what* a VNet or a server component is. Do explain *how this project's specific configuration works*, why we chose *these specific settings*, and what the production implementation looks like beyond the textbook description. The bridge between concept and production is the gap I most want to close.

---

## Switching devices

The repo (git) is the cross-device source of truth. Auto-memory at `~/.claude/projects/.../memory/` is local to each install and does NOT sync — this file (CLAUDE.md) carries the cross-device context, especially the "Current phase" section above.

On a new device, before resuming work:

```bash
# 1. Pull latest project state — CLAUDE.md, docs/, code, infra
git pull

# 2. Verify auth on the toolchain
gh auth status                # GitHub
az account show               # Azure (run `az login` if not authed)

# 3. Check terraform can read state
cd infra/environments/prod
terraform init                # picks up backend.tf
terraform state list          # should match the live env

# 4. Skim recent project state to catch up
git log --oneline -20
cat docs/changelog.md         # narrative record of what was built
ls docs/mentor/               # latest mentor messages = where the cadence left off
```

The first Claude Code session on the new device will have empty auto-memory. That's expected — the "Current phase" section above + the mentor messages bring Claude up to speed. Memory will rebuild naturally as you work on that device.

---

## Goals for this project (in priority order)

1. **Learn the full stack deeply enough to defend it in architect interviews.** I want to understand what each service does, why we chose it over alternatives, how it's configured, and what its operational characteristics are. Every box in the architecture diagram should be one I can talk about for ten minutes from real experience.

2. **Build something operationally excellent that I'm proud of.** Properly backed up, monitored, secured, IaC-managed, with real observability. Infra discipline is my comfort zone — this should reflect that.

3. **Ship a real public service.** Lives at a real URL, real people could use it. Even a niche launch is a win.

4. **Become functional (not expert) at modern app development.** Enough fluency to maintain my own codebase, debug issues, read code. Not aiming for app-dev mastery.

**The product is the vehicle for the architectural learning.** When trade-offs arise between "ship faster" and "learn deeper," default to learn deeper. Speed is not the priority. Understanding is.

---

## How to work with me

This is the most important section. Re-read when in doubt.

### Hands-on cadence for Phase 2 infra (effective 2026-05-13, revised 2026-06-03)

**Brian writes the code and makes the decisions; Claude mentors and reviews.** This flips the prior "Claude builds, Brian reviews" model.

Per-step loop:

1. Claude writes a mentor file at `docs/mentor/m{module}-s{step}-{topic}.md` containing:
   - Decision sections ([D#]) — textbook line / production reality / recommended pick per decision
   - A **"Resources to write"** section listing each resource by type and logical name, key arguments, non-obvious requirements (e.g. required delegations, settings that look wrong but are mandatory), and a link to the relevant Terraform provider doc
   - **No HCL syntax to copy-paste.** Argument names go in prose, not in code blocks.
2. Brian writes the `.tf` file from scratch using the mentor file + provider docs, and decides [D#] values.
3. Brian runs `terraform fmt` and sends back for review.
4. Claude reviews (sign off / push back / flag gaps).
5. Brian runs `terraform plan`, then `apply`.
6. Brian drafts the service doc (`docs/services/<thing>.md`) + changelog entry; Claude edits line-by-line with reasoning.
7. ADRs: same pattern — Brian drafts, Claude edits.

After deciding, Brian fills in the "Decisions Brian made" section at the bottom of each mentor file.

**Why no scaffold?** The keystroke reps and the forced doc-reading are the point. A scaffold with [D#] placeholders looks helpful but short-circuits both. Typing every argument and looking up syntax in the provider docs is what builds the muscle memory that interview-defensibility depends on.

**Exception — editing existing files:** when modifying a `.tf` file that already exists (refactor, adding a resource to an existing module, fixing a bug), Claude can edit directly. The "Brian writes from scratch" rule applies to new files.

**What stays Claude-driven:** audit/inventory commands (`az ...`, `terraform state list`), file moves, repo plumbing. The line: **if the action embeds a decision, Brian makes it.**

### Pedagogical by default — for everything

Teach as you build. This applies to **both infra and app dev** — I want to learn the whole stack, not just the parts I'm weaker on. When producing code or config, explain:

- **What** the code does (especially anything non-obvious)
- **Why** we're doing it this way (the reasoning, not just the mechanics)
- **What alternatives existed** and why this one fits our situation
- **What configuration choices** were made and what would change if we picked differently

Calibration check: I have textbook/cert vocabulary. Don't explain "what is a VNet" at a fundamentals level. DO explain "here's how *we're* configuring this VNet, here's *why* these specific subnets, here's what changes if we add a fourth tier later." Bridge from concept to production.

Skip truly trivial things (basic if statements, etc.). Use judgment.

### Always discuss alternatives

When making a non-trivial choice — library, service tier, config pattern, architectural approach — briefly mention the alternatives I'm not picking and why. Two or three sentences. The point is for me to understand the *space* of options, not just the chosen path.

### Document as we build

Documentation is a first-class deliverable, not an afterthought. See **Documentation requirements** below for structure. When you scaffold new infra or introduce a new pattern, generate or update the corresponding doc in the same change. A change isn't done until the docs reflect it.

### Small, focused changes

I review every line. Big multi-feature dumps are hard to review and easy to miss bugs in. Prefer prompt → produce → review → commit cycles in small steps.

### Be honest about uncertainty

If you don't know an Azure resource property, a Prisma API, or a Next.js convention — say so and search docs. Hallucinated APIs that look plausible are the most expensive bug class in vibe-coded projects, and they also teach me wrong things, which is worse than the bug.

### Push back when I'm wrong

If I propose something that violates conventions in this file, has a real problem, or is solving the wrong layer — say so directly. I'd rather hear it now than ship a bug or learn the wrong lesson.

---

## Documentation requirements

This project has four kinds of documentation:

1. **Reference docs** — how each service/library works *in this project*
2. **Architectural Decision Records (ADRs)** — why we chose what we chose
3. **Operational runbooks** — how to actually run the thing
4. **Build changelog** — narrative record of what was built each step and why

All four live under `docs/`. Maintain them as code changes.

When completing a build step, add a section to `docs/changelog.md` covering: what the step produced, what non-obvious decisions were made, what configuration choices mean, and what was verified. This is the pedagogical record — future sessions and future-me should be able to read it and understand not just what was done but why.

Also keep `docs/architecture.md` updated whenever the architecture meaningfully changes — new services added, deployment topology changes, or current-vs-target state shifts.

### Service reference docs (`docs/services/`)

For each major service, library, or component, maintain a doc following this template:

````markdown
# [Service Name]

## What it is
One paragraph: definition, what category of thing it is, where it sits in our stack.

## Why we use it
What problem it solves *for this project specifically*.

## How it's configured here
- Key settings with rationale
- File locations of the relevant config
- Non-default values and why

## Mental model
The 2-3 concepts you need to hold in your head to reason about this service.

## Alternatives considered
What else could have filled this slot, and why we didn't pick them.

## Common operations
Day-2 ops we'll actually do — deploy, migrate, rotate, scale, debug.

## Gotchas
Things that surprised us or that the docs don't make obvious.

## Cost characteristics
What drives the bill, current tier, when we'd scale up or down.

## Authoritative docs
Links to official docs and key reference pages.
````

Files to create as we deploy/integrate each:

```
docs/services/
  azure-front-door.md
  azure-container-apps.md
  azure-container-registry.md
  azure-postgres-flexible.md
  azure-blob-storage.md
  azure-key-vault.md
  azure-monitor.md
  log-analytics.md
  application-insights.md
  managed-identity.md
  terraform.md
  github-actions.md
  nextjs.md
  prisma.md
  nextauth.md
  tailwind-shadcn.md
  resend.md
  sharp.md
```

### Architectural Decision Records (`docs/decisions/`)

For non-obvious architectural choices, write a short ADR:

````markdown
# ADR-NNNN: [Decision Title]

## Status
Proposed | Accepted | Superseded by ADR-XXXX

## Context
What forced this decision? What constraints are at play? What did we know at the time?

## Decision
What we chose.

## Consequences
What this enables. What this forecloses. What operational burden it adds. What new risks it introduces.

## Alternatives considered
What else was on the table, and why we didn't pick them.
````

Number sequentially. Never delete a superseded ADR — mark it and write a new one. The trail of decisions is part of what I'll review later.

ADRs likely to be written early:
- ADR-0001: Use Next.js App Router (vs Pages Router, Rails, Django)
- ADR-0002: Prisma as the ORM (vs Drizzle, raw SQL)
- ADR-0003: Skip Redis in v1
- ADR-0004: Skip App Gateway in v1, Front Door → Container Apps directly
- ADR-0005: Single environment (prod) in v1, structure for dev/staging
- ADR-0006: EAV vs JSONB for hobby-specific attributes
- ADR-0007: NextAuth over Lucia / Clerk / Auth0
- ADR-0008: Container Apps over App Service / AKS / VM
- ADR-0009: Azure-managed Postgres over self-hosted

### Architecture overview (`docs/architecture.md`)

A single living doc containing:
- High-level architecture diagram (Mermaid)
- Each tier described briefly (edge, ingress, app, data, integration, observability)
- Network topology with subnet purposes
- Data flow walkthrough for the 2-3 most common request types
- Current state vs target state, with what triggers movement between

Update when the architecture meaningfully changes.

### Operational runbooks (`docs/operations/`)

How to actually operate the thing. Add as we go.

```
docs/operations/
  deploy.md          # how a deploy works, how to roll back
  backups.md         # strategy, verification, restore procedure (TESTED)
  secrets.md         # rotation, location, access control
  incidents.md       # known failure modes and response
  cost.md            # monthly breakdown, what to watch, scaling triggers
  observability.md   # what we log, where dashboards live, key queries
```

These should read like a real ops runbook — assume future-me has forgotten everything.

---

## Tech stack (committed)

### Application
- **Framework:** Next.js 16 (App Router, server components by default)
- **Language:** TypeScript, strict mode
- **Styling:** Tailwind CSS + shadcn/ui (components copied into the repo, not installed as a dep)
- **Icons:** Lucide React
- **Forms:** React Hook Form + Zod for validation
- **ORM:** Prisma
- **Auth:** NextAuth (Auth.js v5), Google + GitHub OAuth providers
- **Image processing:** Sharp (resize, optimize, EXIF strip on upload)

### Data
- **Primary DB:** Azure Database for PostgreSQL Flexible Server (B1ms tier in v1)
- **Object Storage:** Azure Blob Storage, separate containers per image size (thumb / feed / full / original)
- **Vector search:** `pgvector` extension installed but unused until v3

### Infrastructure
- **Hosting:** Azure Container Apps (scale-to-zero enabled)
- **Container Registry:** Azure Container Registry
- **Edge:** Azure Front Door Standard (WAF, CDN, TLS termination)
- **Secrets:** Azure Key Vault, read via Container Apps managed identity at startup. Never `.env` files in prod.
- **Monitoring:** Application Insights + Log Analytics workspace (single workspace, all components ship logs to it)
- **IaC:** Terraform with reusable modules. Only `environments/prod/` deployed in v1; `dev/` and `staging/` structured but not provisioned.
- **CI/CD:** GitHub Actions, separate pipelines for infra and app

### Email
- **Transactional:** Resend (free tier sufficient for v1)

When introducing any new dependency or service, write or update its `docs/services/[name].md` in the same change.

---

## What's deliberately NOT in v1 (deferred, with documented v2+ triggers)

These are decisions, not oversights. Don't add them unless explicitly asked. If a request would expand into one of these areas, flag it and confirm before proceeding. Each should have an ADR explaining the deferral.

- **Redis.** Postgres handles sessions, caching, and queues (`pg-boss`) at v1 scale. Trigger to add: measured contention or latency on a hot path that caching demonstrably solves.
- **Azure App Gateway.** Front Door → Container Apps directly in v1. Trigger to add: need for path-based routing between multiple backends, mTLS to backend, or WAF rules richer than Front Door provides.
- **Dev / staging environments.** Terraform structure supports them; only prod is deployed. Trigger: a migration or change scary enough that I want a non-prod environment to test it first.
- **Recommendation engine, taste twins, cross-hobby feed.** v3 features. Newest-first feeds in v1.
- **Multiple hobbies.** v1 launches with ONE hobby. Schema supports many; UI surfaces the launch hobby only.
- **Native mobile apps.** Mobile-responsive web only. PWA capabilities cheap to add later.
- **Payments / paid tier.** Defer until clear product-market fit signal.
- **Dedicated search infrastructure.** Postgres FTS sufficient through ~100k products. Trigger to add Meilisearch: relevance complaints we can't tune away.
- **Lists / curated collections feature.** Possibly cut from v1; confirm scope before adding.

---

## Data model (v1 tables)

The schema reflects the "hobbies-define-schema" pattern: each `hobby` row owns its own attribute definitions and rating dimensions, so adding a new hobby is data, not code.

```
users          — auth identity + profile
hobbies        — top-level category (audiophile, keyboards, skincare, etc.)
products       — items reviewed/owned, belongs to a hobby
attribute_defs — per-hobby field schema (impedance, switch_type, spf, etc.)
product_attrs  — actual values for a product (EAV pattern — see ADR-0006)
rating_dims    — per-hobby rating axes (bass, comfort, hydration, etc.)
ownerships     — user × product with status (own / used / wishlist)
reviews        — user × product with content + overall rating
review_scores  — per-dimension scores within a review
follows        — user × user social graph
```

`prisma/schema.prisma` is the source of truth.

### Conventions
- Primary keys are `cuid()`, not auto-increment integers.
- Every table has `created_at` and `updated_at`.
- Soft delete (`deleted_at`) for user-generated content. Hard delete elsewhere.
- Foreign keys always have a corresponding index.
- Money/prices stored as integer cents — no floats for currency, ever.
- Migrations reviewed by hand. Test against a copy of prod before applying. No auto-apply on deploy for destructive changes.

---

## Architecture conventions

### Directory structure

```
app/                  # Next.js App Router
  (auth)/             # routes requiring auth
  (public)/           # public routes
  api/                # route handlers (webhooks + external consumers only)
components/
  ui/                 # shadcn primitives
  features/           # domain components (HobbyPicker, ReviewForm, ProductCard, ...)
lib/
  db.ts               # Prisma client singleton
  auth.ts             # NextAuth config
  storage.ts          # Blob Storage upload helpers
  log.ts              # structured logger (App Insights)
  validations/        # Zod schemas, shared between client + server
prisma/
  schema.prisma
  migrations/
infra/
  modules/            # Terraform modules (network, container_app, postgres, storage, monitoring, ...)
  environments/
    prod/             # deployed
    dev/              # structured, not deployed v1
    staging/          # structured, not deployed v1
.github/workflows/    # CI/CD pipelines
docs/
  architecture.md
  services/
  decisions/
  operations/
scripts/
```

### Code style
- TypeScript strict mode. No `any` without an inline justification comment.
- Server components by default. Mark `'use client'` only when needed (hooks, browser APIs, interactivity).
- Mutations via server actions. Route handlers only for webhooks and external consumers.
- Validation via Zod schemas, shared between client and server.
- No client-side fetching of owned data — use server components or server actions.
- Tailwind classes inline. Avoid separate `.css` modules.
- File naming: kebab-case for files, PascalCase for component names inside.
- Database access only through `lib/db.ts`. Never instantiate `PrismaClient` elsewhere.

### Error handling
- Server actions return `{ ok: true, data }` or `{ ok: false, error }`. Don't throw across the network boundary.
- Errors logged to Application Insights with structured context (user ID if known, action, params snapshot — minus PII).
- User-facing error messages are friendly. Technical details only in logs.

---

## Security must-haves

These are the paths where AI-generated code goes subtly wrong most often. I read every line in these areas personally — and I want each of these areas explained as we build them, since they're prime "concept-to-production" territory.

1. **Auth flows.** Session handling, OAuth callback validation, CSRF. Trust NextAuth defaults; never bypass them. No custom auth logic without explicit discussion.
2. **File uploads.** MIME type validation server-side (don't trust the client), size limits enforced before reading body, EXIF stripped via Sharp, stored under content-hash filenames (never user-supplied names). Serve from Blob Storage behind Front Door — never from app origin.
3. **Authorization.** Every server action validates that the current user has permission to act on the target resource. No "trust the client passed the right ID" patterns.
4. **SQL injection.** Always use Prisma's typed query API. If raw SQL is unavoidable, use `Prisma.sql` template literals — never string interpolation.
5. **Secrets.** Never in code. Never in `.env` checked into git. Never in logs or error messages. Loaded from Key Vault at startup via managed identity. Document rotation procedure in `docs/operations/secrets.md`.
6. **PII handling.** Email addresses and OAuth tokens are sensitive. Don't include them in logs, error messages, analytics events, or client payloads beyond what the user owns.
7. **Rate limiting.** Defer Front Door WAF rate-limit rules until we see abuse, but the architecture supports adding without app changes.

---

## Testing strategy

Coverage is targeted, not exhaustive.

- **Vitest** for unit tests on pure logic — validation schemas, utility functions, math.
- **Playwright** for e2e on critical paths only: sign-up, sign-in, post a review, follow a user, upload an image. Run on PR.
- **Test DB:** dedicated Postgres instance for tests, reset between runs.
- **Skip:** UI snapshot tests, exhaustive component tests, anything testing the framework rather than my code.
- **Never skip:** auth, authorization checks, file upload validation, payment logic (when added).

---

## Observability conventions

Given the architect career goal, observability is first-class. This is also one of the highest-leverage learning areas — proper observability is what separates "I deployed something" from "I operate something."

- **Application Insights** for distributed tracing. Every server action and route handler creates a span with structured properties.
- **Log Analytics** is the unified sink. Front Door, Container Apps, Postgres, Blob Storage all ship logs to the same workspace.
- **Structured logging** in app code: log objects (JSON), not concatenated strings. Use `lib/log.ts` — don't `console.log` in committed code.
- **Required context fields** on every log: `userId` if known, `requestId`, `action`, `result`. Add domain-specific fields as relevant.
- **PII never in logs.** Hash or omit emails, names, raw OAuth tokens.
- **Workbooks** for dashboards. KQL queries committed to `infra/observability/queries/` as code.
- **Alerts** start minimal: error rate spike, p95 latency on key endpoints, deploy failures. Expand only when there's signal worth alerting on.
- Document our observability setup in `docs/operations/observability.md` — what we log, what we trace, where to find dashboards, key queries.

---

## Common commands

```bash
# Local development
pnpm dev                      # Next.js dev server
pnpm db:push                  # Push schema to dev DB (no migration)
pnpm db:migrate               # Create + run migration
pnpm db:studio                # Prisma Studio
pnpm db:seed                  # Seed launch hobby + anchor products

# Code quality
pnpm lint                     # ESLint
pnpm typecheck                # tsc --noEmit
pnpm format                   # Prettier
pnpm test                     # Vitest
pnpm test:e2e                 # Playwright

# Build & run
pnpm build
pnpm start

# Infrastructure (from infra/environments/prod)
terraform init
terraform plan
terraform apply

# Container build & push (CI handles on merge to main)
./scripts/build-and-push.sh

# Deploy (CI handles on merge to main)
./scripts/deploy.sh
```

---

## v1 scope and rough sequence

Each step has both a code deliverable and a documentation deliverable. A phase isn't "done" until both exist.

1. **Foundations.** Repo init, Next.js scaffold, Tailwind, shadcn, Prisma, NextAuth (Google + GitHub), CI on PR.
   - *Docs:* `services/nextjs.md`, `services/prisma.md`, `services/nextauth.md`, `services/tailwind-shadcn.md`, `services/github-actions.md`. ADR-0001, 0002, 0007.

2. **Infrastructure baseline.** Terraform modules: network, Container Apps, Postgres, Blob, Key Vault, Front Door, monitoring. Deploy prod. Verify dummy app reachable through Front Door end-to-end.
   - *Docs:* All `services/azure-*.md` for what we deploy. `services/terraform.md`, `services/managed-identity.md`. `architecture.md` with current state diagram. `operations/deploy.md`, `operations/backups.md`, `operations/secrets.md`. ADR-0003, 0004, 0005, 0008, 0009.

3. **User & profile.** Sign-up/in flow, profile page (username, bio, avatar), settings.

4. **Hobby & products.** Single launch hobby seeded. Product detail pages with attributes from `product_attrs`.
   - *Docs:* ADR-0006 (EAV vs JSONB).

5. **Ownership tracking.** Toggle on product pages: own / used / wishlist. Surface on profile.

6. **Multi-axis reviews.** Form with per-hobby rating dimensions. Display reviews on product pages with score breakdowns.

7. **Activity feed.** Newest reviews + ownership additions globally. No personalization.

8. **Follow.** Follow/unfollow, follower feed.

9. **Onboarding quiz.** Hobby pick → rapid-fire reactions on hand-curated anchor products → seeded profile → suggested follows.

10. **Search.** Postgres FTS over products and users.
    - *Docs:* Append FTS section to `services/azure-postgres-flexible.md`.

11. **Image uploads.** Sharp pipeline → Blob Storage. Avatars + collection photos.
    - *Docs:* `services/sharp.md`. Update `services/azure-blob-storage.md` with the image pipeline detail.

12. **Polish & launch.** Error states, empty states, loading, mobile, basic SEO metadata.
    - *Docs:* `operations/incidents.md` first version, `operations/cost.md` with actual numbers, `operations/observability.md`.

---

## When to update CLAUDE.md

- After any architectural decision (also write the ADR).
- When a new convention is established that future code should follow.
- When a deferred item moves from "later" to "now."
- When v1 ships, to reflect actual state and prep v2 scope.
- Whenever the answer to a question I asked is one I'd want Claude Code to know automatically next session.

---

*Last updated: 2026-06-03 (end of session) — Module 1 complete. Module 2 Step 1 in progress: `infra/environments/prod/network.tf` is **WIP and not yet correct** — VNet + inline subnet blocks written, several issues identified in review. **Resuming work? Read `docs/mentor/m2-s1-network.md` → "Review notes (2026-06-03)" first** — it has the full punch list (inline subnets need to become standalone `azurerm_subnet` resources, CIDRs overlap, RG reference is missing the map key, etc.) plus the remaining resources to add. Expected resource count after full correct pass: 18. After fixing, run `terraform fmt` + `plan` + send back for review before `apply`. Hands-on cadence revised this session — Claude no longer scaffolds `.tf` files with [D#] placeholders.*
