import "server-only";
import { cache } from "react";
import { redirect } from "next/navigation";
import { apiFetch } from "./api";
import { getToken } from "./session";
import type { Resource, User } from "./types";

/**
 * Verifies the session against the API (the proxy only does an optimistic
 * cookie check) and returns the signed-in user. Only restaurant owners and
 * admins belong in this panel; customers and couriers use the mobile app.
 */
export const getCurrentUser = cache(async (): Promise<User> => {
  if (!(await getToken())) {
    redirect("/login");
  }

  const { data } = await apiFetch<Resource<User>>("/me");

  if (data.role !== "restaurant" && data.role !== "admin") {
    redirect("/session/expired");
  }

  return data;
});

/**
 * Pages for restaurant owners. Admins have their own area. A pending owner
 * may prepare their restaurant and menu but cannot handle orders yet, so
 * pages that need orders pass `allowPending: false`.
 */
export async function requireRestaurantOwner({
  allowPending = false,
}: { allowPending?: boolean } = {}): Promise<User> {
  const user = await getCurrentUser();

  if (user.role === "admin") {
    redirect("/admin");
  }
  if (user.status === "pending" && !allowPending) {
    redirect("/restaurant");
  }

  return user;
}

export async function requireAdmin(): Promise<User> {
  const user = await getCurrentUser();

  if (user.role !== "admin") {
    redirect("/orders");
  }

  return user;
}
