# Tailwind CSS + shadcn/ui

## What it is

Two separate but tightly coupled tools that together handle all UI styling and components in this project.

**Tailwind CSS v4** is a utility-first CSS framework. Instead of writing named CSS classes in a stylesheet, you apply low-level utility classes (`p-4`, `rounded-lg`, `text-sm`) directly in JSX. The build step scans the codebase, keeps only the classes actually used, and outputs a minimal CSS bundle.

**shadcn/ui** is a component collection — buttons, inputs, dialogs, avatars, dropdowns — built on top of Radix UI primitives and styled with Tailwind. The distinguishing feature: components are copied into `components/ui/` and owned by this project, not installed as a versioned npm package. You can read, modify, and understand every line.

Both sit in the presentation layer. They have no runtime dependencies on the backend, auth, or database.

## Why we use it

**Tailwind:** Eliminates context-switching between JSX and CSS files. Every styling decision is colocated with the markup it affects. The purging step means unused styles are never shipped. Works naturally with React Server Components since it's just class strings — no runtime JS required.

**shadcn/ui:** Provides accessible, production-quality components without the black box of a third-party component library. Radix UI handles the hard parts of accessibility (keyboard navigation, ARIA attributes, focus management) in the primitives; shadcn layers the visual design on top. Because the code lives in the repo, there are no surprise breaking changes from upstream — you upgrade on your schedule.

## How it's configured here

**Tailwind v4 — CSS-based configuration (important)**

There is no `tailwind.config.ts` in this project. Tailwind v4 moved all configuration into CSS. The entry point is `app/globals.css`:

```css
@import "tailwindcss";          /* Tailwind core */
@import "tw-animate-css";       /* Animation utilities */
@import "shadcn/tailwind.css";  /* shadcn base styles */
```

All theme tokens are defined in the `@theme inline` block in that file — colors, radius, fonts. If you need to add a custom color or spacing value, it goes there as a CSS custom property.

**OKLCH colors (not HSL)**

shadcn v4 uses OKLCH color values instead of HSL. OKLCH is a perceptually uniform color space — equal numeric steps produce equal visual lightness steps, which is not true in HSL. All color tokens in `globals.css` look like `oklch(0.205 0 0)` (lightness, chroma, hue). Don't convert them to hex or HSL — the perceptual uniformity is the point.

**`components.json`** — shadcn's configuration file. Key settings:

| Field | Value | Meaning |
|---|---|---|
| `style` | `radix-nova` | Nova preset: Lucide icons, Geist font, neutral palette |
| `rsc` | `true` | Components are compatible with React Server Components |
| `tailwind.css` | `app/globals.css` | Where Tailwind theme tokens live |
| `baseColor` | `neutral` | Gray scale from Tailwind's neutral palette |
| `cssVariables` | `true` | Colors are CSS custom properties, not hardcoded |
| `iconLibrary` | `lucide` | Lucide React, per CLAUDE.md |

**Installed components** (in `components/ui/`):

| Component | File | Notes |
|---|---|---|
| Button | `button.tsx` | 6 variants, 6 sizes, `asChild` support |
| Avatar | `avatar.tsx` | Image with fallback, badge, group variants |

**`lib/utils.ts` — the `cn()` function**

Every component uses this:
```ts
import { cn } from "@/lib/utils"
```

`cn()` combines two libraries: `clsx` (merges conditional class arrays into a string) and `tailwind-merge` (deduplicates conflicting Tailwind utilities — if you pass both `p-2` and `p-4`, tailwind-merge keeps only `p-4`). Without tailwind-merge, CSS specificity rules would make the order of classes unpredictable.

## Mental model

Three things to hold in your head:

1. **Theme tokens flow from CSS → Tailwind → components.** `globals.css` defines `--primary` as an OKLCH value. The `@theme inline` block exposes it as `--color-primary`. Tailwind makes it available as the `primary` color utility (`bg-primary`, `text-primary`). Components use those utilities. To change the primary color, change one CSS variable in `globals.css`.

2. **`'use client'` is component-specific, not a blanket rule.** `Button` has no `'use client'` — it's pure HTML with class strings, usable in server components. `Avatar` has `'use client'` because Radix UI's Avatar primitive uses hooks internally to track image load state (loaded, error, fallback). You don't add `'use client'` to components; the components declare it themselves if they need it. You add it to *your* components only when they need React hooks or event handlers.

3. **`asChild` renders styles on a different element.** `<Button asChild><Link href="/login">Sign in</Link></Button>` renders a `<Link>` (which becomes an `<a>`) with all the button's CSS classes applied. You get the button appearance with the correct HTML semantics. This is Radix UI's `Slot` pattern.

## Alternatives considered

**CSS Modules:** Per-component scoped stylesheets. More explicit, no utility class memorization required. We chose Tailwind because colocated styles reduce file-switching overhead, and the utility classes are small enough to scan in context.

**Vanilla CSS / global stylesheets:** Would work for v1 scale. Doesn't compose well as component count grows, and doesn't produce an optimal bundle.

**MUI / Chakra / Mantine:** Full component libraries with their own design systems. All are installed as npm packages — you get updates automatically but can't easily modify internals. Harder to make look "not like a template." shadcn's copy-into-repo model gives more control.

**Plain Radix UI without shadcn:** Would require writing all the Tailwind styling ourselves. shadcn is the styling layer on top of Radix — we get the accessibility for free and the style customizability.

See ADR-0001 for the overall framework decision context.

## Common operations

```bash
# Add a new shadcn component
pnpm dlx shadcn@latest add [component-name]

# Examples
pnpm dlx shadcn@latest add input
pnpm dlx shadcn@latest add dialog
pnpm dlx shadcn@latest add dropdown-menu
```

Components are added to `components/ui/[name].tsx`. They are then yours to modify.

To customize a theme token (e.g., change the primary color):
1. Open `app/globals.css`
2. Find `--primary:` in the `:root` block
3. Change the OKLCH value
4. The change cascades through every component that uses `bg-primary`, `text-primary`, etc.

## Gotchas

- **No `tailwind.config.ts`.** Every tutorial written before 2025 shows editing this file. It doesn't exist in Tailwind v4 projects. Custom tokens go in `app/globals.css` under `@theme inline`.

- **shadcn is listed as a runtime dependency.** The `shadcn` package appears in `dependencies` in `package.json`. This is how shadcn v4 ships its base CSS (`shadcn/tailwind.css` imported in `globals.css`). It's slightly unusual but intentional — shadcn now ships as a proper package, not just a CLI tool.

- **Avatar requires `'use client'`.** If you try to use `Avatar` in a pure server component and see an error about client boundaries, it's because Radix UI's Avatar tracks image loading state internally with hooks. Wrap the component that uses Avatar in `'use client'`, or create a thin client wrapper around it.

- **OKLCH browser support.** OKLCH is supported in all modern browsers (Chrome 111+, Firefox 113+, Safari 15.4+). If you ever see color-related rendering differences in old browsers, OKLCH is the likely cause. Not a concern for v1.

- **`tw-animate-css` replaces `tailwindcss-animate`.** Older shadcn tutorials reference `tailwindcss-animate`. We use `tw-animate-css`, which is the Tailwind v4-compatible replacement. Already configured in `globals.css`.

## Cost characteristics

Both Tailwind and shadcn are free and open source. No licensing cost at any scale. Build-time impact: Tailwind v4 with Turbopack is fast; adding components does not meaningfully affect build time since unused code is tree-shaken.

## Authoritative docs

- https://tailwindcss.com/docs (v4)
- https://ui.shadcn.com/docs
- https://ui.shadcn.com/docs/installation/next (Next.js-specific setup)
- https://www.radix-ui.com/primitives (the accessibility layer underneath)
