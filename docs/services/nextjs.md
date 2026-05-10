# Next.js

## What it is

Next.js is a React framework that adds server-side capabilities to React: file-based routing, server components, server actions, API route handlers, and build tooling. It sits at the top of our application tier — every browser request hits Next.js first. We use the App Router (introduced in Next.js 13, now the standard), which uses React Server Components by default.

## Why we use it

We need server-rendered pages (for SEO and initial load performance), a place to run server-side auth logic, and a way to talk to Postgres without exposing database credentials to the browser. Next.js gives us all three without running a separate backend server. The alternative would be Next.js for the frontend + a separate Node/Express/Fastify API — more operational surface area for no benefit at v1 scale.

## How it's configured here

**Version:** 16.2.6 (pinned in `package.json`)

**Key files:**
- `next.config.ts` — minimal for now; will grow when we add image domains and environment variable validation
- `tsconfig.json` — strict TypeScript, `bundler` module resolution (required for Next.js 16), `@/*` path alias pointing to repo root
- `postcss.config.mjs` — uses `@tailwindcss/postcss` (Tailwind v4's PostCSS plugin; replaces the old `tailwindcss` plugin)
- `app/globals.css` — Tailwind v4 CSS-based config via `@import "tailwindcss"` and `@theme inline` (see Tailwind section below)

**Non-default choices:**
- `--no-src-dir` — `app/`, `components/`, `lib/` live at the repo root, not under `src/`. Matches CLAUDE.md directory conventions.
- `--import-alias "@/*"` — maps `@/lib/db` to `./lib/db.ts` etc. shadcn uses this convention too.

**Runtime target:** Node.js 22 LTS (pinned in `.nvmrc`). `.gitattributes` enforces LF line endings.

## Mental model

Three things to hold in your head:

1. **Server components vs client components.** By default, every file in `app/` is a server component — it runs on the server, has access to environment variables and Prisma, never ships its code to the browser. To use React hooks or browser APIs, you add `'use client'` at the top. The rule: reach for server components first; only add `'use client'` when you actually need hooks or interactivity.

2. **The request lifecycle in App Router.** Browser request → Next.js routing (file system matches to `app/` segments) → layout hierarchy renders (outermost layout first) → page renders → streamed to browser. Server actions (mutations) go through a separate POST mechanism; they don't need route handlers.

3. **Server actions replace most route handlers.** When you submit a form or click a button that modifies data, you call a server action (a function marked `'use server'`). This runs server-side, talks to Prisma, and returns a result. Route handlers (`app/api/`) are only for webhooks and external consumers (things not initiated by our own UI).

## Alternatives considered

- **Pages Router (still Next.js):** The older Next.js model. Would work, but we'd lose server components, get a worse data-fetching story, and learn a pattern that Vercel is clearly sunsetting. No upside.
- **Remix:** Similar server-first philosophy, strong data loading model. Smaller ecosystem and shadcn doesn't target it as a first-class integration. Would be a reasonable choice for a different team.
- **Rails / Django:** Would require learning a second language/framework ecosystem in parallel. The goal is depth on the modern JS stack, not breadth.

See ADR-0001 for the full decision record.

## Common operations

```bash
pnpm dev          # Start dev server (Turbopack by default in v16)
pnpm build        # Production build — runs type checks, lint as part of the process
pnpm start        # Run the production build locally
pnpm typecheck    # tsc --noEmit: type checks without emitting files
pnpm lint         # ESLint with eslint-config-next
```

Adding a new page: create `app/(group)/my-route/page.tsx`. The route group `(group)` is a folder convention that groups routes without adding to the URL path — we use `(auth)` and `(public)` per CLAUDE.md conventions.

Adding a new server action: create a function in a `actions/` file or inline in a server component, mark it `'use server'`, call it from a client component or form.

## Gotchas

- **Tailwind v4 has no `tailwind.config.ts`.** All theme customization goes in `app/globals.css` under `@theme inline`. If you're following a tutorial that shows editing `tailwind.config.ts`, that's Tailwind v3 — the file doesn't exist in our project.

- **`next-env.d.ts` is auto-generated.** It's git-ignored for this reason. Never edit it manually.

- **The `proxy.ts` file (renamed from `middleware.ts` in Next.js 16).** Auth session checking in Next.js 16 uses `proxy.ts` at the repo root instead of `middleware.ts`. See `docs/services/nextauth.md` for how we wire this up with Auth.js.

- **Server components can't use `useState`, `useEffect`, or event handlers.** These are browser/React runtime features. If you try to add one and TypeScript doesn't catch it first, you'll get a runtime error. The fix is always to add `'use client'`.

- **Hot reload vs hard reload.** `pnpm dev` uses Turbopack for fast module replacement. If you see stale state, try a hard browser refresh before assuming a bug.

## Cost characteristics

Next.js itself is free and open source. Cost is driven by hosting (Azure Container Apps — see `docs/services/azure-container-apps.md`) and any Vercel-specific features we're not using (we host on Azure, not Vercel). Turbopack build time is fast; cold start time on Container Apps with scale-to-zero is the main latency concern.

## Authoritative docs

- https://nextjs.org/docs (App Router section)
- https://nextjs.org/docs/app/building-your-application/upgrading/version-16 (v16 migration guide — covers async APIs and proxy.ts rename)
- https://react.dev/reference/rsc/server-components
