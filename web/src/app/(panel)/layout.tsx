import { Suspense } from "react";
import { logout } from "../(auth)/actions";
import { NavLinks, type NavLink } from "@/components/nav-links";
import { getCurrentUser } from "@/lib/dal";
import type { User } from "@/lib/types";

export default function PanelLayout({ children }: LayoutProps<"/">) {
  return (
    <>
      <header className="border-b border-zinc-200 bg-white dark:border-zinc-800 dark:bg-zinc-950">
        <div className="mx-auto flex max-w-6xl flex-wrap items-center justify-between gap-3 px-4 py-3">
          <span className="font-semibold tracking-tight text-orange-600">SuperApp Delivery</span>
          <Suspense fallback={<div className="h-9 w-64" aria-hidden />}>
            <HeaderBar />
          </Suspense>
        </div>
      </header>
      <Suspense fallback={null}>
        <AccountNotice />
      </Suspense>
      <main className="mx-auto w-full max-w-6xl flex-1 px-4 py-6">{children}</main>
    </>
  );
}

function linksFor(user: User): NavLink[] {
  if (user.role === "admin") {
    return [{ href: "/admin", label: "Cuentas" }];
  }

  // A pending restaurant can prepare its profile and menu, but has no orders yet.
  const setup = [
    { href: "/menu", label: "Menú" },
    { href: "/restaurant", label: "Restaurante" },
  ];
  return user.status === "pending" ? setup : [{ href: "/orders", label: "Pedidos" }, ...setup];
}

async function HeaderBar() {
  const user = await getCurrentUser();

  return (
    <div className="flex flex-1 flex-wrap items-center justify-between gap-3">
      <NavLinks links={linksFor(user)} />
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
    </div>
  );
}

async function AccountNotice() {
  const user = await getCurrentUser();

  if (user.role !== "restaurant" || user.status !== "pending") {
    return null;
  }

  return (
    <div role="status" className="border-b border-amber-200 bg-amber-50 text-amber-900 dark:border-amber-900 dark:bg-amber-950 dark:text-amber-200">
      <p className="mx-auto max-w-6xl px-4 py-2 text-sm">
        <strong>Tu cuenta está en revisión.</strong> Mientras tanto puedes preparar tu restaurante y tu menú; los clientes los verán y podrás recibir pedidos cuando un administrador la apruebe.
      </p>
    </div>
  );
}
