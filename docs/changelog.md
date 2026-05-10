# Build changelog

Narrative record of each build step — what was done, why, and what the non-obvious decisions were. Meant to be readable after the fact, not just a git log.

---

## Phase 1: Foundations

### Step 1 — Next.js scaffold, Tailwind v4, tooling baseline
*Commit: `0f973db`*

#### Environment decisions made before writing any code

**Node.js 20 → 22 LTS.** pnpm 11 (what corepack installs by default) requires Node ≥ 22.13. Node 22 LTS (Jod) was installed via nvm and set as the new default. `.nvmrc` pins the project to Node 22 so future terminal sessions auto-switch. Node 20 is still installed and available for other projects.

**Next.js 15 → 16.** `create-next-app@latest` installs Next.js 16 as of May 2026. Chose to follow latest rather than pin to 15, to avoid accumulating upgrade debt before shipping anything. Risk: Auth.js v5 + Next.js 16 compatibility is not officially documented (open issue #13302) — accepted and noted in ADR-0007 (to be written in Step 5).

**Tailwind v4 confirmed.** `create-next-app` with Next.js 16 scaffolds Tailwind v4. shadcn `@latest` supports v4 natively. No compatibility fork to navigate.

#### What the scaffold created

**`app/layout.tsx`** — the root layout that wraps every page. Uses Geist (Vercel's typeface) loaded through `next/font/google`, which handles subsetting, self-hosting, and CSS variable injection automatically. `--font-geist-sans` appears as a CSS variable in `globals.css` — that's `next/font` writing into the Tailwind theme.

**`app/globals.css`** — this is how Tailwind v4 works, and it differs from every tutorial written before 2025. Instead of `@tailwind base; @tailwind components; @tailwind utilities;` plus a separate `tailwind.config.ts`, Tailwind v4 uses a single CSS import (`@import "tailwindcss"`) and a CSS-native `@theme inline` block for customization. No `tailwind.config.ts` exists in this project. All theme tokens live in CSS. This matters when reading shadcn docs — the shadcn v4 components use this same convention.

**`tsconfig.json`** — `"strict": true` was already in the scaffold (Next.js 16 default). Strict mode means no implicit `any`, no implicit `undefined`, strict null checks. TypeScript catches things that would otherwise be runtime errors.

**`pnpm-workspace.yaml`** — pnpm 11 introduced a security model where native build scripts (postinstall hooks that compile native binaries) are denied by default. `sharp` and `unrs-resolver` both need their build scripts to run. We approved them explicitly in `pnpm-workspace.yaml` rather than blanket-enabling all scripts.

#### What we added

**`.gitattributes`** — tells Git "regardless of what OS you're on, store and check out all text files with LF endings." Without this, Windows Git would convert LF→CRLF on checkout, which Docker and WSL bash scripts would misread. Binary entries prevent Git from trying to diff image or font files as text.

**`.nvmrc` with `22`** — when you `cd` into this directory in a terminal that has nvm's auto-use hook configured, Node automatically switches to 22. Without it, you'd need to remember `nvm use 22` every session.

**`typecheck` script** — `tsc --noEmit` runs the TypeScript compiler without emitting files, purely for checking types. `pnpm build` also type-checks, but it's a full production build — much slower. `typecheck` is for the fast feedback loop during development.

**`docs/services/nextjs.md`** and **`docs/decisions/ADR-0001.md`** — Phase 1 requires these before the step is "done."

#### What we updated

**`app/page.tsx`** — replaced the default Next.js showcase page with a minimal placeholder. The real home page (with auth state) comes in Step 6.

**`CLAUDE.md`** — Next.js 15 → 16 in the tech stack section.

#### Verified
- `pnpm dev` → Next.js 16.2.6 with Turbopack, ready in 383ms
- `pnpm typecheck` → zero errors

#### Notes
`README.md` still contains the default "bootstrapped with create-next-app" content. It will be replaced with real project documentation later in the project.

---

### Step 2 — shadcn/ui initialization, Tailwind v4 theme, component baseline
*Commit: `1b205d4`*

#### What the init did

**`components.json`** — shadcn's project configuration. Tells the CLI where your CSS lives, what import alias you use, which icon library, and which preset. Key values: `"style": "radix-nova"` (Nova preset — Lucide icons + Geist font), `"rsc": true` (components are Server Component compatible by default), `"cssVariables": true` (colors are CSS custom properties, not hardcoded values).

**`app/globals.css` — extended with the shadcn theme.** Three new imports were added on top of the existing `@import "tailwindcss"`:
- `@import "tw-animate-css"` — animation utilities (Tailwind v4 replacement for `tailwindcss-animate`)
- `@import "shadcn/tailwind.css"` — shadcn's base reset and component styles
- `@custom-variant dark` — defines `.dark` class-based dark mode

The `@theme inline` block was extended with the full set of color tokens (`--color-primary`, `--color-muted`, `--color-destructive`, etc.) and a radius scale. All color values are **OKLCH** — a perceptually uniform color space where equal numeric steps produce equal visual lightness changes (HSL does not have this property). To change the app's primary color, change `--primary` in the `:root` block.

**`lib/utils.ts` — the `cn()` function.** Every shadcn component uses this. It combines `clsx` (joins conditional class arrays into a string) and `tailwind-merge` (deduplicates conflicting Tailwind utilities — if both `p-2` and `p-4` are passed, `tailwind-merge` keeps only `p-4`). Without `tailwind-merge`, the last class in the CSS file wins, which is non-obvious and hard to debug.

#### Components installed

**`components/ui/button.tsx`** — installed by the Nova preset init automatically. Uses `cva` (class-variance-authority) to define variants (`default`, `outline`, `secondary`, `ghost`, `destructive`, `link`) and sizes (`xs`, `sm`, `default`, `lg`, `icon`, `icon-sm`, `icon-lg`) as a type-safe API — TypeScript will reject invalid variant/size combinations. Also supports `asChild`: passing `asChild` renders button styles on a child element instead (e.g., a `<Link>` that looks like a button). No `'use client'` — usable in server components.

**`components/ui/avatar.tsx`** — added separately for Step 6. Built on Radix UI's Avatar primitive, which handles image loading state (loaded → show image, error → show fallback, loading → show nothing until resolved). Exports `Avatar`, `AvatarImage`, `AvatarFallback`, `AvatarBadge`, `AvatarGroup`, `AvatarGroupCount`. Has `'use client'` because the Radix primitive uses hooks internally to track image load state.

#### The pnpm 11 build script pattern

This was the second time the same pnpm 11 security model blocked native build scripts. `msw` (Mock Service Worker — a transitive dependency pulled in by shadcn) needed approval alongside the `sharp` and `unrs-resolver` approvals from Step 1. Each new package with a native build script needs a one-line addition to `pnpm-workspace.yaml`. This is working as intended — pnpm 11 requires explicit opt-in for each package rather than blanket trust.

#### Verified
- `pnpm typecheck` → zero errors
- `components/ui/button.tsx`, `components/ui/avatar.tsx`, `lib/utils.ts` present
- `globals.css` updated with full OKLCH theme token set

---

### Step 3 — Docker Compose, Postgres 16, local database
*Commit: `7d62531`*

#### What was created

**`docker-compose.yml`** — defines a single `postgres` service using the `postgres:16-alpine` image. Alpine variant is used because it's ~50% smaller than the full Debian-based image with no functional difference for our use case.

Key settings:
- `restart: unless-stopped` — container restarts automatically after `docker compose up -d`, even after Docker Desktop restarts, unless you explicitly stop it with `docker compose down`
- `POSTGRES_USER / PASSWORD / DB` — credentials and database name for local dev only; not production credentials
- `5432:5432` — maps the container's Postgres port to the same port on localhost, so `localhost:5432` works from the app
- Named volume `postgres_data` — data persists between container restarts. Without a named volume, every `docker compose down` would wipe the database
- `healthcheck` — polls `pg_isready` every 5 seconds so `docker compose ps` shows `(healthy)` once Postgres is fully initialized (not just started). Prisma will use this in Step 4 to know the DB is ready

**`.env.local`** — gitignored (matches `.env*` in `.gitignore`). Contains the `DATABASE_URL` Prisma needs to connect. For local dev: `postgresql://lifestack:lifestack_dev@localhost:5432/lifestack`. In production this value comes from Azure Key Vault, not a file.

**`.env.example`** — committed to the repo. Documents every environment variable the project needs, with placeholder values. Serves as the canonical list of what to populate when setting up a new dev environment. Updated each time a new env var is added.

#### Why Postgres 16 specifically

Azure Database for PostgreSQL Flexible Server supports up to Postgres 16. Running the same version locally eliminates a class of compatibility bugs — a SQL feature or behavior that works in the local Docker container is guaranteed to work in production. Never run a different Postgres version locally than you run in production.

#### Docker architecture note

The container runs inside Docker Desktop's Linux VM on Windows, but the WSL2 integration makes it transparent: `docker` commands from the WSL terminal talk directly to the Docker daemon, and `localhost:5432` from the Next.js app (also running in WSL) resolves to the container. The data volume (`lifestack_postgres_data`) lives in Docker's VM storage, not in the WSL filesystem — which is why you manage it with `docker volume` commands rather than finding it on disk.

#### Day-2 operations

```bash
docker compose up -d          # Start Postgres in the background
docker compose down           # Stop container (data volume preserved)
docker compose down -v        # Stop AND delete the data volume (full reset)
docker compose ps             # Check status and health
docker compose logs postgres  # View Postgres logs
docker compose exec postgres psql -U lifestack -d lifestack  # Open psql shell
```

#### Verified
- `docker compose ps` → `(healthy)`, port `0.0.0.0:5432->5432/tcp`
- `pg_isready -U lifestack -d lifestack` → accepting connections

---

### Step 4 — Prisma 6, schema, first migration, db singleton
*Commit: `22e28c6`*

#### Version decision: Prisma 6, not 7

Prisma 7 (the latest) was initially installed, but it made a breaking architectural change: the `url` field was removed from the `datasource` block in `schema.prisma`. Prisma 7 requires a new `prisma.config.ts` driver pattern that is not yet documented in combination with Auth.js v5. We downgraded to Prisma 6 — the stable, well-documented version that all Auth.js adapter examples target. The pnpm install output will suggest upgrading to v7; ignore it until Auth.js explicitly confirms compatibility. See ADR-0002.

#### The env file problem (and how we solved it)

Prisma CLI reads `.env` by default, not `.env.local`. Prisma 6 had a `--env-file` flag; Prisma 7 removed it. Rather than duplicate `DATABASE_URL` into both `.env` and `.env.local`, all `db:*` scripts in `package.json` are prefixed with `dotenv -e .env.local --`, which loads the right file before passing control to Prisma. Single source of truth for the variable, no duplication.

#### What was created

**`prisma/schema.prisma`** — the four models Auth.js v5 requires: `User`, `Account`, `Session`, `VerificationToken`. Field names match exactly what `@auth/prisma-adapter` expects — the adapter reads these model names and field names directly when making queries.

Added to the adapter's baseline schema per CLAUDE.md conventions:
- `@default(cuid())` on User.id — CUID strings instead of auto-increment. CUIDs are collision-resistant and don't expose row counts.
- `createdAt` / `updatedAt` on User, Account, Session — `@updatedAt` tells Prisma to set this automatically on every write.
- `@@index([userId])` on Account and Session — CLAUDE.md requires an index on every FK column. Prisma doesn't add these automatically.
- `onDelete: Cascade` on Account and Session — deleting a User cleans up their sessions and OAuth tokens automatically.

Skipped: the `Authenticator` model (WebAuthn/passkeys). Not used in v1 — Google + GitHub OAuth only.

**`prisma/migrations/20260510065410_init/migration.sql`** — the SQL Prisma generated from the schema. Four `CREATE TABLE` statements, indexes, and foreign key constraints. This file is committed to git — it's the authoritative record of what the database looks like. Never edit it by hand.

**`lib/db.ts`** — the Prisma client singleton. The `global` trick stores the client on Node's global object in development so Next.js hot reloads reuse the same database connection pool instead of creating a new one on every file change. In production the module is only loaded once, so the trick is harmless.

**`pnpm-workspace.yaml`** — approved build scripts for `@prisma/engines`, `prisma`, and `@prisma/client`. These packages compile native binaries for query execution; they're safe and required.

#### Verified
- `pnpm db:migrate --name init` → migration `20260510065410_init` created and applied
- Tables confirmed in Postgres: `User`, `Account`, `Session`, `VerificationToken`
- `pnpm typecheck` → zero errors

---

### Step 5 — Auth.js v5, Google + GitHub OAuth, Prisma-backed sessions
*Commit: `0a22c0b`*

#### What was created

**`lib/auth.ts`** — the entire Auth.js configuration in 10 lines. `NextAuth()` returns four exports: `handlers` (the GET/POST route handlers), `auth` (reads the current session anywhere — server components, server actions, proxy), `signIn` and `signOut` (server actions to start/end sessions). The Prisma adapter is wired in so OAuth accounts and sessions are stored in Postgres. Google and GitHub are the only providers.

**`app/api/auth/[...nextauth]/route.ts`** — two lines. The `[...nextauth]` catch-all dynamic route matches every path under `/api/auth/`: `/api/auth/callback/google`, `/api/auth/callback/github`, `/api/auth/signin`, `/api/auth/signout`, and others. Auth.js handles all of them internally via the `handlers` export. We never write logic here.

**`proxy.ts`** — Next.js 16's renamed `middleware.ts`. Exporting `auth as proxy` makes Auth.js check for a valid session on every request and handle unauthenticated redirects. Initially this file also exported `runtime = "nodejs"` as "explicit documentation" — Step 6 caught Next.js 16 actively rejecting that route segment config and the line was removed. The proxy is always Node.js in Next.js 16; the Prisma adapter works without any runtime opt-in.

**`.env.local`** — added `AUTH_SECRET` (generated with `openssl rand -base64 32`) and placeholders for `AUTH_GOOGLE_ID`, `AUTH_GOOGLE_SECRET`, `AUTH_GITHUB_ID`, `AUTH_GITHUB_SECRET`. Auth.js v5 auto-detects the `AUTH_{PROVIDER}_{ID|SECRET}` naming convention.

**`.env.example`** — corrected the OAuth variable names from the v4 convention (`GOOGLE_CLIENT_ID`) to the v5 convention (`AUTH_GOOGLE_ID`). These are different and Auth.js v5 will not pick up the old names.

#### No split config needed

Earlier research flagged a potential split config requirement: in Next.js pre-16, middleware ran on the Edge runtime which can't hit a database, so session checking in middleware required JWT (not database sessions). In Next.js 16, the proxy runs on Node.js runtime, so the Prisma adapter works there directly. Single config, database sessions throughout. No JWT workaround needed.

#### How the OAuth flow works

1. User clicks "Sign in with Google" → our app calls `signIn("google")` → Next.js redirects to Google's authorization URL with a `state` parameter (CSRF protection)
2. User authenticates on Google → Google redirects to `/api/auth/callback/google?code=...&state=...`
3. Auth.js validates the `state`, exchanges the `code` for tokens, fetches the user profile from Google
4. Auth.js upserts a `User` row (matched by email) and an `Account` row (the OAuth link)
5. Auth.js creates a `Session` row in Postgres, sets a session cookie
6. User is redirected to the app, now authenticated

Every subsequent request: `proxy.ts` calls `auth()` → Prisma looks up the session token → returns the session or null.

#### Verified
- `pnpm typecheck` → zero errors
- All four files created: `lib/auth.ts`, `app/api/auth/[...nextauth]/route.ts`, `proxy.ts`, `.env.local` updated

---

### Step 6 — Auth-aware home page, sign-in / sign-out, Phase 1 complete
*Commit: `b363e6e`*

#### What was created

**`app/page.tsx`** — replaced the placeholder with a server component that calls `await auth()` and branches on session state.

- **Signed out:** "Lifestack" headline + two buttons ("Continue with Google", "Continue with GitHub"). Each button is wrapped in a `<form>` whose `action` is an inline server action that calls `signIn("google", { redirectTo: "/" })` or `signIn("github", …)`.
- **Signed in:** Avatar (image with initials fallback) + "Signed in as <name>" + a sign-out button (same form / server-action pattern wrapping `signOut`).

No `'use client'` anywhere — the entire home page renders on the server.

#### Why server actions in form `action` props (not a client component)

Auth.js v5's `signIn` and `signOut` are server-side functions: they need access to cookies, `AUTH_SECRET`, and the database. The form-action pattern hands the click off to the server without making the page interactive on the client, which keeps the entire home page on the server boundary.

The alternatives we didn't pick:
- **`'use client'` + `next-auth/react`'s client-side `signIn`** — works, but it's the JWT-session pattern (the client lib reads sessions from cookies via JS). We're using database sessions, so we want the server to be the only thing that talks to the session table.
- **Client component that POSTs to `/api/auth/signin/<provider>` directly** — bypasses the convenience helpers and re-implements the flow in our own code. More fragile, more code, no benefit.

The inline `"use server"` directive at the top of the action function body is the documented Auth.js v5 idiom for App Router.

#### Avatar with image + initials fallback

`getInitials()` takes the first two whitespace-separated tokens of the name, takes the first letter of each, uppercases. Missing or unparseable name falls back to `?`. Radix's Avatar primitive automatically swaps to `AvatarFallback` when `AvatarImage` fails to load (or has no `src`), so we get image-with-graceful-fallback behavior for free — no manual loading-state plumbing.

The Avatar `size` prop variants top out at `lg` (40px); for the focal-point avatar on the home page we override via `className="size-16"` (64px). `tailwind-merge` (via `cn()`) drops the variant's `size-8` and keeps `size-16`.

#### Why text-only buttons (no Google / GitHub icons)

Lucide doesn't ship a Google glyph (Lucide is a UI-symbol library, not a brand-icon library). Pulling in `react-icons` or inlining brand SVGs for two buttons isn't worth the dependency or the visual-fidelity gymnastics. Easy to add later if Step 12 (polish) wants it.

#### Correction from Step 5: `proxy.ts` runtime export removed

Step 5 added `export const runtime = "nodejs"` to `proxy.ts` framed as "explicit documentation". The smoke test for Step 6 caught Next.js 16 actively rejecting it:

```
⨯ Route segment config is not allowed in Proxy file at "./proxy.ts". Proxy always runs on Node.js runtime.
```

The proxy is always Node.js in Next.js 16 — there is no separate Edge variant for proxy files (unlike Next.js 15's `middleware.ts`, which defaulted to Edge and required an explicit Node.js opt-in). The export is now removed; `proxy.ts` is a single line. Updated `docs/services/nextauth.md` and `docs/decisions/ADR-0007.md` to match.

#### Pending — OAuth credentials

`AUTH_GOOGLE_ID`, `AUTH_GOOGLE_SECRET`, `AUTH_GITHUB_ID`, `AUTH_GITHUB_SECRET` are still empty in `.env.local`. The page renders fine and the buttons display correctly, but clicking either provider will fail at Auth.js's "no client_id configured" check until those are populated. Once filled in, the full sign-in / sign-out flow works end-to-end against the local dev server.

#### Verified

- `pnpm typecheck` → zero errors
- `pnpm dev` → Ready in 383ms; `GET /` returns HTTP 200 with the expected signed-out copy ("Lifestack", "Sign in to continue", "Continue with Google", "Continue with GitHub")
- Dev server log clean after the `proxy.ts` correction — no warnings, no errors

#### Phase 1 done

Working local dev loop end-to-end:
- Next.js 16 dev server with Turbopack
- Postgres 16 in Docker, healthy and persistent across restarts
- Prisma 6 schema with the four Auth.js models, first migration applied
- Auth.js v5 with Google + GitHub providers wired in, Prisma-backed sessions
- Home page that branches on auth state, signed-in showing avatar + name

Phase 2 (infrastructure baseline — Terraform modules, Azure deploy, Front Door, etc.) is the next chunk of work and has not been started.

---

## Phase 2: Infrastructure baseline

Each sub-step provisions one slice of the architecture and ships with a corresponding service doc and ADR (where the decision is non-obvious). v1 deploys only the prod environment; dev and staging are structured into the Terraform layout but not provisioned.

### Step 2.1 — Subscription, provider registration
*Commit: `910f581`*

#### Why a dedicated subscription

The default Azure subscription on the user's account already had an unrelated personal project. Best-practice for any production-scoped workload — and especially for one we want clean cost reporting on — is a dedicated subscription per workload per environment. Reasons:

- **Blast radius isolation.** Accidental destroy operations only affect the project sub.
- **Cost reporting.** Per-subscription billing reports show real Lifestack monthly cost without filtering — enables Phase-12's `docs/operations/cost.md` deliverable.
- **Quota isolation.** Postgres, Container Apps, and Front Door regional quotas are per-subscription.
- **Career-goal alignment.** "One sub per workload per environment" is the standard enterprise topology — setting it up that way now is the concept-to-production bridge for the architect track.

The user already had two subscriptions visible. The non-default one ("Subscription 1") was audited via `az resource list` / `az group list` / `az role assignment list` and found completely empty — zero resource groups, zero resources, zero custom RBAC. It was renamed to `Lifestack` via the portal and adopted as the v1 prod target.

#### Subscription details

- Name: `Lifestack`
- ID: `4bae3a60-95fa-468b-8088-95fd0d23311e`
- Tenant: `8f06ae15-e337-408c-abe2-da17244ad3a8`
- Type: pay-as-you-go (shared billing account with the user's other sub)

#### Resource providers registered

Azure resource providers must be registered in a subscription before you can create resources of those types. Most register on demand on first use, but registering up-front avoids a 2–3 minute wait on the first `terraform apply`. Nine providers registered (all completed in ~20 seconds):

- `Microsoft.App` — Container Apps
- `Microsoft.Cdn` — Front Door (Standard/Premium tier sits under Microsoft.Cdn)
- `Microsoft.ContainerRegistry` — ACR
- `Microsoft.DBforPostgreSQL` — Postgres Flexible Server
- `microsoft.insights` — Application Insights (lowercase namespace, an Azure naming oddity)
- `Microsoft.KeyVault` — Key Vault
- `Microsoft.Network` — VNet, NSG, Private Endpoint, Private DNS Zones
- `Microsoft.OperationalInsights` — Log Analytics
- `Microsoft.Storage` — Blob Storage

#### Verified

- `az account show --query name` → `Lifestack`
- All 9 providers in `Registered` state

---

### Step 2.2 — Terraform state backend, `infra/` skeleton
*Commit: `910f581`*

#### What was created

**State backend (bootstrapped via `az` CLI, not Terraform — chicken-and-egg):**

- Resource Group: `rg-lifestack-tfstate` (East US)
- Storage Account: `stlifestack9k3l` (Standard_LRS)
- Container: `tfstate`
- State blob key: `prod.tfstate`

**Why bootstrap via `az` CLI instead of Terraform.** Terraform needs a state backend to run. The state backend itself can't be Terraform-managed unless we provision it with local state and migrate (`terraform init -migrate-state`). Bootstrapping via `az` CLI is HashiCorp's documented pattern — the state SA is treated as one-time pre-Terraform infrastructure, outside the Terraform-managed estate. Cleaner, fewer steps, no dual-state to reconcile.

**Security posture on the state SA — locked down from creation:**

- `httpsOnly: true`, `minTls: TLS1_2` — no plaintext or weak crypto
- `allowBlobPublicAccess: false` — no anonymous reads at any scope
- `allowSharedKeyAccess: false` — no shared-key auth, AAD only
- Blob versioning enabled — every state-modifying apply creates a recoverable version
- 7-day soft delete on container and blob deletion — accidentally `terraform destroy`-ing the state is recoverable for a week
- "Storage Blob Data Contributor" role granted to the team member's user OID

The Owner-vs-data-plane subtlety bit immediately: subscription Owner is a control-plane role only. With shared-key auth disabled, the only way to read/write blobs is via AAD, which requires a Storage Blob Data role explicitly assigned. Owner-on-the-sub does *not* cover this — the role assignment was a required step, not a nicety.

**Terraform skeleton in `infra/environments/prod/`:**

- `versions.tf` — Terraform `~> 1.15`, AzureRM `~> 4.0`, Random `~> 3.6`
- `backend.tf` — AzureRM backend pinned to the state SA, with `use_azuread_auth = true` (mandatory because shared-key is disabled)
- `main.tf` — provider config block: `prevent_deletion_if_contains_resources = true` on RGs (safety against `terraform destroy` typos), `purge_soft_delete_on_destroy = false` and `recover_soft_deleted_key_vaults = true` on Key Vault (recoverability)
- `variables.tf` — `subscription_id`, `location`, `environment`, `project` inputs
- `terraform.tfvars` — sub ID committed (non-secret per Microsoft guidance)
- `infra/.gitignore` — ignores `.terraform/`, `*.tfstate*`, `*.tfplan`; explicitly notes `.terraform.lock.hcl` is committed

#### Naming convention locked in

Following the Microsoft Cloud Adoption Framework abbreviations. Documented in full in `docs/services/terraform.md`. Pattern: `<type>-lifestack-<purpose|env>` for resources that allow hyphens, `<type>lifestack<purpose>{rand}` for resources that don't (storage accounts, ACR). The 4-char `{rand}` suffix is needed for resources whose names are globally unique across all of Azure (storage accounts, ACR, Key Vault, Front Door endpoint).

#### Auth model

- **Local dev:** `az login` → AzureRM provider auto-detects CLI auth → state backend uses the same identity for AAD blob ops
- **CI (Phase 2.x, not yet wired):** GitHub Actions → workload identity / OIDC federation → AzureRM provider with no static credentials

#### Verified

- `terraform init` → providers downloaded (AzureRM 4.72.0, Random 3.8.1), backend connected, `.terraform.lock.hcl` generated
- `terraform validate` → "Success! The configuration is valid."
- `terraform plan` → "No changes. Your infrastructure matches the configuration." State lock acquired and released — confirms AAD auth and SA access work end-to-end
- `az storage container exists --auth-mode login` against the state SA → `true` (data-plane RBAC propagated correctly)

#### Cost so far

- State SA (Standard_LRS, KB-sized state files): ~$0.02/month
- No app-side resources provisioned yet

---

### Step 2.2.1 — Subscription budget (cost guardrail)
*Commit: `TBD`*

#### What was created

A `$100/month` subscription-scoped budget (`lifestack-monthly`) with three alert thresholds:

| Threshold | Trigger | Why |
|---|---|---|
| 80% actual ($80) | `GreaterThan` | Yellow flag — getting close, intervene if trend continues |
| 100% actual ($100) | `GreaterThanOrEqualTo` | Already over — escalate |
| 100% forecasted | `GreaterThan` | Mid-month projection-based — fires earlier than actual when trajectory is bad, gives time to adjust before overrun |

All three notify `brian.ky.lee@outlook.com`. Time period: 2026-05-01 to 2030-05-01.

#### Important: budgets alert, they don't cap

Azure pay-as-you-go has no built-in "stop everything when threshold hit" feature — that exists only on free trial / MSDN / sponsorship subscriptions. For a hard cap, you'd need a custom Action Group plus Automation runbook to deallocate or stop resources when the alert fires. v1 stays alert-only; manual intervention is acceptable for a personally-monitored project. Documented as a deferred hardening item.

#### Why Terraform (not `az` CLI)

The state backend was bootstrapped via `az` CLI because of the Terraform chicken-and-egg. The budget has no such constraint — it's a normal subscription resource that fits cleanly into the Terraform-managed estate. Defining it via the `azurerm_consumption_budget_subscription` resource means:

- Future budget-threshold tweaks are PR-reviewable diffs
- The budget is recreated automatically if anyone deletes it via portal
- Naming/tagging stays consistent with the rest of the IaC

This is also the **first real Terraform apply** in the project — exercises the full IaC pipeline end-to-end: AzureRM provider auth via `az login`, state backend reads/writes via AAD, ARM API resource creation, state writeback to the backend SA. Everything green in 5 seconds.

#### Verified

- `terraform plan` → "1 to add, 0 to change, 0 to destroy"
- `terraform apply` → resource created in 5s, state writeback succeeded
- `az consumption budget list --query "[?name=='lifestack-monthly']"` → returns the budget with all three notifications populated, `currentSpend: $0.00`

#### Cost
- Budget itself: free
- Updated subscription cost so far: ~$0.02/month (still just the state SA)

