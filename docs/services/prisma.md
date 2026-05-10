# Prisma

## What it is

Prisma is an ORM (Object-Relational Mapper) for TypeScript. It sits between the application code and PostgreSQL, providing a type-safe query API generated from the schema file at `prisma/schema.prisma`. Prisma has two distinct parts: the **CLI** (dev tooling — runs migrations, generates the client, opens Studio) and the **client** (runtime library — the object your code imports to run queries).

## Why we use it

Three reasons for this project specifically:

1. **Type safety end-to-end.** Prisma generates TypeScript types from the schema. When you query `db.user.findUnique({ where: { id } })`, TypeScript knows the exact shape of what comes back — including which fields are nullable. This catches a class of bugs (wrong field names, wrong types, missing null checks) at compile time rather than runtime.

2. **Managed migrations.** `pnpm db:migrate` generates a SQL migration file from schema changes, applies it, and tracks which migrations have run. The migration files live in `prisma/migrations/` and are committed — the full history of every schema change is in git.

3. **Auth.js adapter compatibility.** `@auth/prisma-adapter` expects a Prisma client and translates Auth.js session/account operations into Prisma calls. The schema models (User, Account, Session, VerificationToken) are defined by the adapter's contract.

## How it's configured here

**Version:** Prisma 6.x (intentionally pinned — see Gotchas).

**Key files:**

| File | Purpose |
|---|---|
| `prisma/schema.prisma` | Schema definition — single source of truth for the database structure |
| `prisma/migrations/` | SQL migration history — every schema change that has ever been applied |
| `lib/db.ts` | Prisma client singleton — the only place in the codebase that instantiates `PrismaClient` |
| `.env.local` | `DATABASE_URL` for local dev (gitignored) |

**Schema conventions (from CLAUDE.md):**
- Primary keys: `@id @default(cuid())` — CUID strings, not auto-increment integers. CUIDs are collision-resistant, URL-safe, and don't expose row counts.
- Timestamps: every model has `createdAt DateTime @default(now())` and `updatedAt DateTime @updatedAt`. Prisma's `@updatedAt` updates automatically on every write.
- Foreign key indexes: every FK column has a corresponding `@@index`. This is our convention; Prisma doesn't add indexes automatically.
- Cascade deletes: `onDelete: Cascade` on Account and Session so that deleting a User cleans up their sessions and OAuth accounts.

**The `--env-file` situation:**
Prisma CLI doesn't read `.env.local` by default (it reads `.env`). Rather than duplicate `DATABASE_URL` into two files, all `db:*` scripts in `package.json` are prefixed with `dotenv -e .env.local --` to load the right file. `db:generate` is the exception — it doesn't need a database connection, so it runs without dotenv.

**`lib/db.ts` — the singleton pattern:**
```ts
const globalForPrisma = global as unknown as { prisma: PrismaClient }

export const db =
  globalForPrisma.prisma ??
  new PrismaClient({ log: ["query", "error", "warn"] })

if (process.env.NODE_ENV !== "production") globalForPrisma.prisma = db
```
In development, Next.js hot reloads modules on every file change. Without the `global` trick, each reload would create a new `PrismaClient` instance and a new database connection pool — you'd exhaust the connection limit quickly. Storing the client on `global` means reloads reuse the existing instance. In production, the module is only loaded once so the trick isn't needed (and `global` assignments in production would just be noise).

## Mental model

Three things to hold in your head:

1. **The schema is the contract.** `prisma/schema.prisma` defines what exists in the database. When you change the schema, you run `pnpm db:migrate` to generate and apply the SQL. Never edit the database directly — always go through migrations so the history stays consistent.

2. **The generated client knows your schema.** After every schema change, Prisma regenerates the TypeScript client. If you add a field to `User` in the schema and run `pnpm db:generate` (or `pnpm db:migrate` which runs generate automatically), `db.user.findUnique()` immediately returns that new field with the correct type.

3. **`db` is imported from `lib/db.ts`, always.** Never do `new PrismaClient()` anywhere else in the codebase. The singleton file is the single import point.

## Alternatives considered

**Drizzle ORM:** SQL-first ORM with strong TypeScript support. Requires writing SQL-like syntax directly. More explicit, smaller runtime, no code generation step. We chose Prisma because the schema-first workflow (define in schema, generate client) is easier to follow when learning, and Auth.js has a first-class Prisma adapter. Drizzle would be a reasonable choice for a team already comfortable with SQL.

**Raw SQL with `pg`:** Maximum control, no abstraction overhead. Ruled out because we'd lose type safety on queries and would need to write all migrations by hand.

See ADR-0002 for the full decision record.

## Common operations

```bash
# Make a schema change, then:
pnpm db:migrate            # Generates migration SQL + applies it + regenerates client
                           # Prompts for a migration name

pnpm db:generate           # Regenerate client without touching the DB (after manual schema edits)
pnpm db:studio             # Open Prisma Studio (visual DB browser) at localhost:5555
pnpm db:push               # Push schema directly to DB without creating a migration file
                           # Use only for rapid prototyping — not for tracked changes

# Inspect the live database:
docker compose exec postgres psql -U lifestack -d lifestack
\dt                        # List tables
SELECT * FROM "User";      # Query (note: table names are quoted, case-sensitive)
```

**Reviewing a migration before applying:** `pnpm db:migrate --create-only` generates the SQL without applying it. Read the file in `prisma/migrations/`, then run `pnpm db:migrate` to apply.

## Gotchas

- **Prisma 7 is a breaking change — we're on 6.** Prisma 7 removed the `url` field from the datasource block in `schema.prisma`, requiring a new `prisma.config.ts` driver architecture. This is not yet well-supported in combination with Auth.js v5 and standard Next.js patterns. We're pinned to `^6` intentionally. Upgrade to 7 only when Auth.js explicitly documents compatibility.

- **Migrate vs push.** `db:push` applies schema changes directly to the database without creating a migration file. It's useful for exploring schema ideas locally but should not be used for changes you intend to keep — use `db:migrate` instead. `pnpm db:push` will warn you if it would destroy data.

- **The Prisma client must be regenerated after schema changes.** `pnpm db:migrate` does this automatically. If you ever edit `schema.prisma` without migrating (unusual), run `pnpm db:generate` manually or TypeScript will be working from a stale client definition.

- **Table names are quoted in raw SQL.** Prisma uses PascalCase model names (`User`, `Account`) which map to quoted PostgreSQL table names `"User"`, `"Account"`. In `psql`, you must quote them: `SELECT * FROM "User";` not `SELECT * FROM User;`.

- **`dotenv-cli` is a dev dependency.** The `db:*` scripts depend on `dotenv-cli` being installed. It's in `devDependencies` — if you ever run `pnpm install --prod`, these scripts won't work. This is only a concern in production contexts, where Prisma CLI commands shouldn't be run anyway.

## Cost characteristics

Prisma OSS is free. Prisma Accelerate (their connection pooling/caching cloud product) is not used — we connect directly to Postgres. At v1 scale, direct connections are fine. If we hit connection exhaustion (visible in Postgres logs and App Insights), Prisma Accelerate or PgBouncer are the options.

## Authoritative docs

- https://www.prisma.io/docs (Prisma 6)
- https://www.prisma.io/docs/orm/prisma-schema/overview
- https://www.prisma.io/docs/orm/prisma-migrate/getting-started
- https://authjs.dev/getting-started/adapters/prisma (Auth.js adapter schema reference)
