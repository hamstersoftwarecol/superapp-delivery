"use client";

import { useActionState } from "react";
import { forgotPassword } from "../actions";
import { Field } from "@/components/field";
import { SubmitButton } from "@/components/submit-button";

export function ForgotPasswordForm() {
  const [state, action] = useActionState(forgotPassword, undefined);

  if (state?.notice) {
    return (
      <p role="status" className="rounded-lg bg-green-50 px-3 py-2 text-sm text-green-700 dark:bg-green-950 dark:text-green-300">
        {state.notice} Revisa también la carpeta de correo no deseado.
      </p>
    );
  }

  return (
    <form action={action} className="space-y-4">
      {state?.error && (
        <p role="alert" className="rounded-lg bg-red-50 px-3 py-2 text-sm text-red-700 dark:bg-red-950 dark:text-red-300">
          {state.error}
        </p>
      )}
      <Field label="Correo de tu cuenta" name="email" type="email" autoComplete="email" required errors={state?.fieldErrors?.email} />
      <SubmitButton className="w-full">Enviar instrucciones</SubmitButton>
    </form>
  );
}
