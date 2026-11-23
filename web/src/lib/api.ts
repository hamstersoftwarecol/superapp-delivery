import "server-only";
import { redirect } from "next/navigation";
import { getToken } from "./session";

const baseUrl = process.env.API_URL ?? "http://localhost:8000/api/v1";

export class ApiError extends Error {
  constructor(
    public readonly status: number,
    message: string,
    public readonly fieldErrors: Record<string, string[]> = {},
    public readonly code?: string,
  ) {
    super(message);
  }
}

type RequestOptions = {
  method?: "GET" | "POST" | "PUT" | "PATCH" | "DELETE";
  body?: unknown;
  token?: string | null;
};

export async function apiFetch<T>(
  path: string,
  { method = "GET", body, token }: RequestOptions = {},
): Promise<T> {
  const authToken = token === undefined ? await getToken() : token;

  let response: Response;
  try {
    response = await fetch(`${baseUrl}${path}`, {
      method,
      cache: "no-store",
      headers: {
        Accept: "application/json",
        ...(body !== undefined && { "Content-Type": "application/json" }),
        ...(authToken && { Authorization: `Bearer ${authToken}` }),
      },
      body: body !== undefined ? JSON.stringify(body) : undefined,
    });
  } catch {
    throw new ApiError(0, "No se pudo conectar con el servidor. Intenta de nuevo.");
  }

  if (response.status === 204) {
    return undefined as T;
  }

  const json = await response.json().catch(() => null);

  if (!response.ok) {
    if (response.status === 401 && authToken) {
      redirect("/session/expired");
    }
    throw new ApiError(
      response.status,
      response.status === 429
        ? "Demasiados intentos. Espera un minuto e inténtalo de nuevo."
        : (json?.message ?? "Ocurrió un error inesperado."),
      json?.errors ?? {},
      json?.code,
    );
  }

  return json as T;
}
