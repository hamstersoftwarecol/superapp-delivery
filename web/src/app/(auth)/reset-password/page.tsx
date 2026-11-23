import type { Metadata } from "next";
import Link from "next/link";
import { Suspense } from "react";
import { ResetPasswordForm } from "./reset-form";

export const metadata: Metadata = { title: "Nueva contraseña" };

export default function ResetPasswordPage({ searchParams }: PageProps<"/reset-password">) {
  return (
    <>
      <h1 className="mb-4 text-lg font-semibold">Crea tu contraseña nueva</h1>
      <Suspense fallback={<div className="h-40 animate-pulse rounded-lg bg-zinc-100 dark:bg-zinc-900" aria-hidden />}>
        <ResetPasswordContent searchParams={searchParams} />
      </Suspense>
    </>
  );
}

async function ResetPasswordContent({ searchParams }: Pick<PageProps<"/reset-password">, "searchParams">) {
  const { token, email } = await searchParams;

  if (typeof token !== "string" || typeof email !== "string" || !token || !email) {
    return (
      <div className="space-y-3">
        <p role="alert" className="rounded-lg bg-red-50 px-3 py-2 text-sm text-red-700 dark:bg-red-950 dark:text-red-300">
          Este enlace no es válido. Pide uno nuevo.
        </p>
        <Link href="/forgot-password" className="inline-block text-sm font-medium text-orange-600 hover:underline">
          Recuperar mi contraseña
        </Link>
      </div>
    );
  }

  return <ResetPasswordForm token={token} email={email} />;
}
