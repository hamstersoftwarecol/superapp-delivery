"use client";

import Link from "next/link";
import { useActionState } from "react";
import { resetPassword } from "../actions";
import { Field } from "@/components/field";
import { SubmitButton } from "@/components/submit-button";

export function ResetPasswordForm({ token, email }: { token: string; email: string }) {
  const [state, action] = useActionState(resetPassword, undefined);

  if (state?.notice) {
    return (
      <div className="space-y-4">
        <p role="status" className="rounded-lg bg-green-50 px-3 py-2 text-sm text-green-700 dark:bg-green-950 dark:text-green-300">
          {state.notice}
        </p>
        <p className="text-sm text-zinc-500">
          Si usas la app móvil, vuelve a ella e inicia sesión con tu contraseña nueva.
        </p>
        <Link href="/login" className="inline-block text-sm font-medium text-orange-600 hover:underline">
          Ir al panel web
        </Link>
      </div>
    );
  }

  return (
    <form action={action} className="space-y-4">
      <input type="hidden" name="token" value={token} />
      <input type="hidden" name="email" value={email} />

      {state?.error && (
        <p role="alert" className="rounded-lg bg-red-50 px-3 py-2 text-sm text-red-700 dark:bg-red-950 dark:text-red-300">
          {state.error}
        </p>
      )}
      {state?.fieldErrors?.email && (
        <p role="alert" className="rounded-lg bg-red-50 px-3 py-2 text-sm text-red-700 dark:bg-red-950 dark:text-red-300">
          {state.fieldErrors.email[0]}{" "}
          <Link href="/forgot-password" className="font-medium underline">
            Pedir un enlace nuevo
          </Link>
        </p>
      )}

      <p className="text-sm text-zinc-500">
        Cuenta: <span className="font-medium text-zinc-700 dark:text-zinc-300">{email}</span>
      </p>
      <Field label="Contraseña nueva (mínimo 8 caracteres)" name="password" type="password" autoComplete="new-password" required errors={state?.fieldErrors?.password} />
      <Field label="Repite la contraseña" name="password_confirmation" type="password" autoComplete="new-password" required errors={state?.fieldErrors?.password_confirmation} />
      <SubmitButton className="w-full">Guardar contraseña</SubmitButton>
    </form>
  );
}
