"use server";

import { redirect } from "next/navigation";
import { ApiError, apiFetch } from "@/lib/api";
import { clearToken, setToken } from "@/lib/session";
import type { User } from "@/lib/types";

export type FormState =
  | { error?: string; fieldErrors?: Record<string, string[]> }
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

    if (user.role !== "restaurant") {
      await apiFetch("/auth/logout", { method: "POST", token }).catch(() => undefined);
      return { error: "Este panel es solo para restaurantes. Usa la app móvil." };
    }

    await setToken(token);
  } catch (error) {
    if (error instanceof ApiError) {
      return toState(error);
    }
    throw error;
  }

  redirect("/orders");
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
