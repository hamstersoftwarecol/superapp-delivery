import { Suspense } from "react";
import { logout } from "../(auth)/actions";
import { NavLinks } from "@/components/nav-links";
import { getCurrentUser } from "@/lib/dal";

export default function PanelLayout({ children }: LayoutProps<"/">) {
  return (
    <>
      <header className="border-b border-zinc-200 bg-white dark:border-zinc-800 dark:bg-zinc-950">
        <div className="mx-auto flex max-w-6xl flex-wrap items-center justify-between gap-3 px-4 py-3">
          <div className="flex items-center gap-6">
            <span className="font-semibold tracking-tight text-orange-600">SuperApp Delivery</span>
            <NavLinks />
          </div>
          <Suspense fallback={<div className="h-9 w-32" aria-hidden />}>
            <UserBar />
          </Suspense>
        </div>
      </header>
      <main className="mx-auto w-full max-w-6xl flex-1 px-4 py-6">{children}</main>
    </>
  );
}

async function UserBar() {
  const user = await getCurrentUser();

  return (
    <div className="flex items-center gap-3 text-sm">
      <span className="text-zinc-500">{user.name}</span>
      <form action={logout}>
        <button
          type="submit"
          className="rounded-lg px-3 py-2 text-zinc-600 hover:bg-zinc-100 dark:text-zinc-400 dark:hover:bg-zinc-900"
        >
          Salir
        </button>
      </form>
    </div>
  );
}
