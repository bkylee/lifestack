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
*Commits: `TBD`*

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
