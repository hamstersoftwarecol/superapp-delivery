import type { Metadata } from "next";
import Link from "next/link";
import { ForgotPasswordForm } from "./forgot-form";

export const metadata: Metadata = { title: "Recuperar contraseña" };

export default function ForgotPasswordPage() {
  return (
    <>
      <h1 className="mb-1 text-lg font-semibold">Recupera tu contraseña</h1>
      <p className="mb-4 text-sm text-zinc-500">
        Escribe el correo de tu cuenta y te enviaremos un enlace para crear una contraseña nueva.
      </p>
      <ForgotPasswordForm />
      <p className="mt-4 text-center text-sm text-zinc-500">
        <Link href="/login" className="font-medium text-orange-600 hover:underline">
          Volver a iniciar sesión
        </Link>
      </p>
    </>
  );
}
