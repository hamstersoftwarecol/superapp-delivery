import type { Metadata } from "next";
import Link from "next/link";
import { RegisterForm } from "./register-form";

export const metadata: Metadata = { title: "Crear cuenta" };

export default function RegisterPage() {
  return (
    <>
      <h1 className="mb-4 text-lg font-semibold">Registra tu restaurante</h1>
      <RegisterForm />
      <p className="mt-4 text-center text-sm text-zinc-500">
        ¿Ya tienes cuenta?{" "}
        <Link href="/login" className="font-medium text-orange-600 hover:underline">
          Inicia sesión
        </Link>
      </p>
    </>
  );
}
