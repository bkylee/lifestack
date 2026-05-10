export { auth as proxy } from "@/lib/auth"

// Next.js 16 renamed middleware.ts to proxy.ts.
// Explicitly declare Node.js runtime so the Prisma adapter can reach the database
// on session checks — the Edge runtime cannot make direct database connections.
export const runtime = "nodejs"
