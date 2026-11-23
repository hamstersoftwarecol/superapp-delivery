import "server-only";
import { cache } from "react";
import { redirect } from "next/navigation";
import { apiFetch } from "./api";
import { getToken } from "./session";
import type { Resource, User } from "./types";

/**
 * Verifies the session against the API (the proxy only does an optimistic
 * cookie check) and returns the signed-in restaurant owner.
 */
export const getCurrentUser = cache(async (): Promise<User> => {
  if (!(await getToken())) {
    redirect("/login");
  }

  const { data } = await apiFetch<Resource<User>>("/me");

  if (data.role !== "restaurant") {
    redirect("/session/expired");
  }

  return data;
});
