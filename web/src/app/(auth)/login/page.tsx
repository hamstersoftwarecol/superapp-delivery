import type { Metadata } from "next";
import Link from "next/link";
import { LoginForm } from "./login-form";

export const metadata: Metadata = { title: "Iniciar sesión" };

export default function LoginPage() {
  return (
    <>
      <h1 className="mb-4 text-lg font-semibold">Iniciar sesión</h1>
      <LoginForm />
      <p className="mt-4 text-center text-sm text-zinc-500">
        ¿Aún no tienes cuenta?{" "}
        <Link href="/register" className="font-medium text-orange-600 hover:underline">
          Registra tu restaurante
        </Link>
      </p>
    </>
  );
}
