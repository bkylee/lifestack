# Auth.js (NextAuth v5)

## What it is

Auth.js v5 (`next-auth@beta`) is the authentication library for the application. It handles the full OAuth flow with Google and GitHub: redirecting the user to the provider, receiving the OAuth callback, exchanging the authorization code for a user profile, creating or finding the user in the database, and issuing a session. It also handles CSRF protection, session lifecycle, and the proxy-layer session check.

## Why we use it

OAuth has subtle security requirements — state parameter validation, token handling, redirect URI pinning, CSRF protection — where a small mistake can mean account takeover. Auth.js implements all of this correctly so our code doesn't have to. The alternative (rolling custom OAuth) would be both more code and more risk.

The Prisma adapter (`@auth/prisma-adapter`) gives Auth.js a database-backed session store: sessions live in the `Session` table, OAuth account links in the `Account` table. This means sessions survive server restarts and can be revoked by deleting the row.

See ADR-0007 for the choice of Auth.js over Lucia, Clerk, and Auth0.

## How it's configured here

**Version:** `next-auth@5.0.0-beta.31` — still in beta. Not yet a stable release.

**Key files:**

| File | Purpose |
|---|---|
| `lib/auth.ts` | Main config — providers, adapter, callbacks |
| `app/api/auth/[...nextauth]/route.ts` | Catch-all route handler for OAuth callbacks |
| `proxy.ts` | Next.js 16 session check on every request |

**`lib/auth.ts` — the config:**
```ts
export const { handlers, auth, signIn, signOut } = NextAuth({
  adapter: PrismaAdapter(db),
  providers: [Google, GitHub],
})
```

Four exports come out of `NextAuth()`:
- `handlers` — `{ GET, POST }` route handlers used in the API route
- `auth` — async function that returns the current session; used in server components, server actions, and `proxy.ts`
- `signIn` — server action to initiate a sign-in flow
- `signOut` — server action to end a session

**`app/api/auth/[...nextauth]/route.ts`:**
```ts
export const { GET, POST } = handlers
```
The `[...nextauth]` catch-all segment matches every path under `/api/auth/` — `/api/auth/callback/google`, `/api/auth/callback/github`, `/api/auth/signin`, `/api/auth/signout`, etc. Auth.js handles all of these internally; we never write logic here.

**`proxy.ts` — Next.js 16 session routing:**
```ts
export { auth as proxy } from "@/lib/auth"
export const runtime = "nodejs"
```
In Next.js 16, `middleware.ts` was renamed to `proxy.ts`. This file runs on every request before the page renders. Exporting `auth as proxy` tells Auth.js to check for a valid session on each request and handle redirects. `runtime = "nodejs"` is explicit: the Prisma adapter needs a Node.js process to open database connections — the Edge runtime cannot do this.

**Environment variables (all required):**

| Variable | Purpose |
|---|---|
| `AUTH_SECRET` | Signing key for session tokens. Generate with `openssl rand -base64 32`. Never reuse across environments. |
| `AUTH_GOOGLE_ID` | Google OAuth client ID |
| `AUTH_GOOGLE_SECRET` | Google OAuth client secret |
| `AUTH_GITHUB_ID` | GitHub OAuth app client ID |
| `AUTH_GITHUB_SECRET` | GitHub OAuth app client secret |

Auth.js v5 auto-detects the `AUTH_{PROVIDER}_{ID|SECRET}` naming convention — no explicit configuration of these in the providers array is needed.

**Session storage:** Database sessions via Prisma adapter (default when an adapter is configured). Session tokens are stored in the `Session` table. The token is a lookup key; the session data lives in the database row, not in the token itself. This means sessions can be revoked server-side by deleting the row.

## Mental model

Three things to hold in your head:

1. **The OAuth flow is a round trip through the provider.** When a user clicks "Sign in with Google": our app redirects them to Google with a `state` parameter → Google authenticates them → Google redirects back to `/api/auth/callback/google` with a `code` → Auth.js exchanges the code for a profile → Auth.js upserts the User and Account records → Auth.js creates a Session row and sets a cookie. Auth.js handles every step; our code just initiates the redirect and reads the resulting session.

2. **`auth()` is how you read the session.** In any server component or server action: `const session = await auth()`. Returns `null` if not signed in, or a session object with `session.user.id`, `session.user.name`, `session.user.email`, `session.user.image`. The `proxy.ts` also calls `auth()` on every request for route-level protection.

3. **Trust the library defaults.** Auth.js handles CSRF protection, token rotation, and session expiry. Do not add custom logic to the OAuth callbacks unless you have a specific reason. Do not bypass the CSRF checks. Do not store session tokens in localStorage.

## Alternatives considered

See ADR-0007. Short version: Lucia was ruled out (more DIY, smaller ecosystem), Clerk ruled out (hosted service, vendor lock-in, cost at scale), Auth0 ruled out (same concerns as Clerk).

## Common operations

```ts
// Read session in a server component
import { auth } from "@/lib/auth"
const session = await auth()
if (!session) redirect("/")

// Initiate sign-in from a server action or form
import { signIn } from "@/lib/auth"
await signIn("google", { redirectTo: "/dashboard" })
await signIn("github", { redirectTo: "/dashboard" })

// Sign out from a server action
import { signOut } from "@/lib/auth"
await signOut({ redirectTo: "/" })
```

**Adding a new OAuth provider:** install `next-auth/providers/[provider]`, add to the `providers` array in `lib/auth.ts`, add `AUTH_{PROVIDER}_ID` and `AUTH_{PROVIDER}_SECRET` to `.env.local` and Key Vault. No other changes needed.

**Revoking a session:** delete the row from the `Session` table where `sessionToken` matches.

**Rotating `AUTH_SECRET`:** existing sessions become invalid (users get signed out). Acceptable; they re-authenticate. In production, rotate via Key Vault and restart the Container Apps revision.

## Gotchas

- **`next-auth@beta` is not stable.** The API may change before v5 reaches a stable release. Pin the version in `package.json` and review the changelog before upgrading.

- **Next.js 16 compatibility is not officially documented.** Auth.js v5 works with Next.js 16's `proxy.ts` in practice, but there is an open GitHub issue (#13302) about formal support. See ADR-0007.

- **`proxy.ts` not `middleware.ts`.** Any Auth.js tutorial written before mid-2025 will reference `middleware.ts`. In Next.js 16 that file is `proxy.ts` and exports `proxy` not `middleware`.

- **`AUTH_GOOGLE_ID` not `GOOGLE_CLIENT_ID`.** Auth.js v5 uses `AUTH_{PROVIDER}_{ID|SECRET}` naming. The old v4 names (`GOOGLE_CLIENT_ID`, `GITHUB_CLIENT_ID`) do not work.

- **`session.user.id` may be undefined without a callback.** By default, `session.user` contains `name`, `email`, `image` but NOT `id`. To expose the user ID to the client session (needed for authorization checks), add a `session` callback to `lib/auth.ts`. We'll add this when building features that need the user ID client-side.

## Cost characteristics

Auth.js is free and open source. Each authenticated page request triggers one database query (session lookup by token, indexed on `sessionToken`). At v1 scale this is negligible. If session lookup becomes a bottleneck, the first mitigation is a Redis cache in front of the session table (deferred per CLAUDE.md).

## Authoritative docs

- https://authjs.dev/getting-started/installation
- https://authjs.dev/getting-started/frameworks/nextjs
- https://authjs.dev/getting-started/adapters/prisma
- https://authjs.dev/guides/edge-compatibility
