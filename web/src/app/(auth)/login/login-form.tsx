"use client";

import Link from "next/link";
import { useActionState } from "react";
import { login } from "../actions";
import { Field } from "@/components/field";
import { SubmitButton } from "@/components/submit-button";

export function LoginForm() {
  const [state, action] = useActionState(login, undefined);

  return (
    <form action={action} className="space-y-4">
      {state?.error && (
        <p role="alert" className="rounded-lg bg-red-50 px-3 py-2 text-sm text-red-700 dark:bg-red-950 dark:text-red-300">
          {state.error}
        </p>
      )}
      <Field label="Correo" name="email" type="email" autoComplete="email" required errors={state?.fieldErrors?.email} />
      <Field label="Contraseña" name="password" type="password" autoComplete="current-password" required errors={state?.fieldErrors?.password} />
      <SubmitButton className="w-full">Entrar</SubmitButton>
      <p className="text-center text-sm">
        <Link href="/forgot-password" className="text-zinc-500 hover:text-orange-600 hover:underline">
          ¿Olvidaste tu contraseña?
        </Link>
      </p>
    </form>
  );
}
