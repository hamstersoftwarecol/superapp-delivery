"use client";

import { useActionState } from "react";
import { register } from "../actions";
import { Field } from "@/components/field";
import { SubmitButton } from "@/components/submit-button";

export function RegisterForm() {
  const [state, action] = useActionState(register, undefined);

  return (
    <form action={action} className="space-y-4">
      {state?.error && (
        <p role="alert" className="rounded-lg bg-red-50 px-3 py-2 text-sm text-red-700 dark:bg-red-950 dark:text-red-300">
          {state.error}
        </p>
      )}
      <Field label="Tu nombre" name="name" autoComplete="name" required errors={state?.fieldErrors?.name} />
      <Field label="Correo" name="email" type="email" autoComplete="email" required errors={state?.fieldErrors?.email} />
      <Field label="Teléfono (opcional)" name="phone" type="tel" autoComplete="tel" errors={state?.fieldErrors?.phone} />
      <Field label="Contraseña (mínimo 8 caracteres)" name="password" type="password" autoComplete="new-password" required errors={state?.fieldErrors?.password} />
      <SubmitButton className="w-full">Crear cuenta</SubmitButton>
    </form>
  );
}
