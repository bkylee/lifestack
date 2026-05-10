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

**`proxy.ts`** — Next.js 16's renamed `middleware.ts`. Exporting `auth as proxy` makes Auth.js check for a valid session on every request and handle unauthenticated redirects. The explicit `runtime = "nodejs"` is necessary: the Prisma adapter opens database connections, which requires Node.js — the Edge runtime cannot do this. Earlier research flagged that Next.js 16 moved the proxy to Node.js runtime by default, but the explicit declaration is documentation.

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
