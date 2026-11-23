"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";

export type NavLink = { href: string; label: string };

export function NavLinks({ links }: { links: NavLink[] }) {
  const pathname = usePathname();

  return (
    <nav aria-label="Principal" className="flex gap-1">
      {links.map(({ href, label }) => {
        const active = pathname.startsWith(href);
        return (
          <Link
            key={href}
            href={href}
            aria-current={active ? "page" : undefined}
            className={`rounded-lg px-3 py-2 text-sm font-medium transition-colors ${
              active
                ? "bg-orange-600/10 text-orange-700 dark:text-orange-400"
                : "text-zinc-600 hover:bg-zinc-100 dark:text-zinc-400 dark:hover:bg-zinc-900"
            }`}
          >
            {label}
          </Link>
        );
      })}
    </nav>
  );
}
