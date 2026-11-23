"use server";

import { redirect } from "next/navigation";
import { ApiError, apiFetch } from "@/lib/api";
import { clearToken, setToken } from "@/lib/session";
import type { User } from "@/lib/types";

export type FormState =
  | { error?: string; fieldErrors?: Record<string, string[]>; notice?: string }
  | undefined;

type AuthResponse = { token: string; user: User };

function toState(error: ApiError): FormState {
  const hasFieldErrors = Object.keys(error.fieldErrors).length > 0;
  return {
    error: hasFieldErrors ? undefined : error.message,
    fieldErrors: error.fieldErrors,
  };
}

export async function login(_previous: FormState, formData: FormData): Promise<FormState> {
  let destination = "/orders";

  try {
    const { token, user } = await apiFetch<AuthResponse>("/auth/login", {
      method: "POST",
      token: null,
      body: {
        email: formData.get("email"),
        password: formData.get("password"),
        device_name: "web-panel",
      },
    });

    if (user.role !== "restaurant" && user.role !== "admin") {
      await apiFetch("/auth/logout", { method: "POST", token }).catch(() => undefined);
      return { error: "Este panel es para restaurantes y administradores. Usa la app móvil." };
    }

    await setToken(token);
    destination = user.role === "admin" ? "/admin" : "/orders";
  } catch (error) {
    if (error instanceof ApiError) {
      return toState(error);
    }
    throw error;
  }

  redirect(destination);
}

export async function register(_previous: FormState, formData: FormData): Promise<FormState> {
  try {
    const { token } = await apiFetch<AuthResponse>("/auth/register", {
      method: "POST",
      token: null,
      body: {
        name: formData.get("name"),
        email: formData.get("email"),
        phone: formData.get("phone") || null,
        password: formData.get("password"),
        role: "restaurant",
      },
    });

    await setToken(token);
  } catch (error) {
    if (error instanceof ApiError) {
      return toState(error);
    }
    throw error;
  }

  redirect("/restaurant");
}

export async function logout(): Promise<void> {
  await apiFetch("/auth/logout", { method: "POST" }).catch(() => undefined);
  await clearToken();
  redirect("/login");
}

export async function forgotPassword(_previous: FormState, formData: FormData): Promise<FormState> {
  try {
    const { message } = await apiFetch<{ message: string }>("/auth/forgot-password", {
      method: "POST",
      token: null,
      body: { email: formData.get("email") },
    });

    return { notice: message };
  } catch (error) {
    if (error instanceof ApiError) {
      return toState(error);
    }
    throw error;
  }
}

export async function resetPassword(_previous: FormState, formData: FormData): Promise<FormState> {
  const password = String(formData.get("password") ?? "");

  if (password !== String(formData.get("password_confirmation") ?? "")) {
    return { fieldErrors: { password_confirmation: ["Las contraseñas no coinciden."] } };
  }

  try {
    const { message } = await apiFetch<{ message: string }>("/auth/reset-password", {
      method: "POST",
      token: null,
      body: {
        email: formData.get("email"),
        token: formData.get("token"),
        password,
      },
    });

    return { notice: message };
  } catch (error) {
    if (error instanceof ApiError) {
      return toState(error);
    }
    throw error;
  }
}
