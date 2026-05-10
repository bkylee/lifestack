import { auth, signIn, signOut } from "@/lib/auth"
import {
  Avatar,
  AvatarFallback,
  AvatarImage,
} from "@/components/ui/avatar"
import { Button } from "@/components/ui/button"

function getInitials(name: string | null | undefined): string {
  if (!name) return "?"
  const parts = name.trim().split(/\s+/).slice(0, 2)
  const initials = parts.map((p) => p[0]?.toUpperCase() ?? "").join("")
  return initials || "?"
}

export default async function Home() {
  const session = await auth()

  if (session?.user) {
    return (
      <main className="flex flex-1 flex-col items-center justify-center gap-6 p-8">
        <Avatar className="size-16">
          {session.user.image && (
            <AvatarImage
              src={session.user.image}
              alt={session.user.name ?? "Profile"}
            />
          )}
          <AvatarFallback>{getInitials(session.user.name)}</AvatarFallback>
        </Avatar>
        <div className="text-center">
          <p className="text-sm text-zinc-500">Signed in as</p>
          <p className="text-lg font-medium">
            {session.user.name ?? session.user.email}
          </p>
        </div>
        <form
          action={async () => {
            "use server"
            await signOut({ redirectTo: "/" })
          }}
        >
          <Button type="submit" variant="outline">
            Sign out
          </Button>
        </form>
      </main>
    )
  }

  return (
    <main className="flex flex-1 flex-col items-center justify-center gap-6 p-8">
      <div className="text-center">
        <h1 className="text-2xl font-medium">Lifestack</h1>
        <p className="mt-1 text-sm text-zinc-500">Sign in to continue</p>
      </div>
      <div className="flex w-64 flex-col gap-2">
        <form
          action={async () => {
            "use server"
            await signIn("google", { redirectTo: "/" })
          }}
        >
          <Button type="submit" className="w-full">
            Continue with Google
          </Button>
        </form>
        <form
          action={async () => {
            "use server"
            await signIn("github", { redirectTo: "/" })
          }}
        >
          <Button type="submit" variant="outline" className="w-full">
            Continue with GitHub
          </Button>
        </form>
      </div>
    </main>
  )
}
