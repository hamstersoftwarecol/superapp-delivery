"use server";

import { revalidatePath } from "next/cache";
import { redirect } from "next/navigation";
import { ApiError, apiFetch } from "@/lib/api";
import { centsFromInput } from "@/lib/format";
import type { Resource, Restaurant } from "@/lib/types";

export type SaveState =
  | { error?: string; fieldErrors?: Record<string, string[]>; saved?: boolean }
  | undefined;

function failTo(path: string, error: unknown): never {
  if (error instanceof ApiError) {
    const separator = path.includes("?") ? "&" : "?";
    redirect(`${path}${separator}error=${encodeURIComponent(error.message)}`);
  }
  throw error;
}

/**
 * Builds the explanation shown to the customer from the preset the restaurant
 * picked and an optional detail. "Otro" has no meaning without the detail.
 */
function reasonFrom(formData: FormData): { reason?: string; error?: string } {
  const preset = String(formData.get("reason") ?? "").trim();
  const detail = String(formData.get("detail") ?? "").trim();

  if (!preset) {
    return {};
  }
  if (preset === "Otro") {
    return detail ? { reason: detail } : { error: "Escribe el motivo." };
  }

  return { reason: detail ? `${preset}: ${detail}` : preset };
}

export async function updateOrderStatus(formData: FormData): Promise<void> {
  const orderId = Number(formData.get("orderId"));
  const status = String(formData.get("status"));
  const { reason, error } = reasonFrom(formData);

  if (error) {
    redirect(`/orders?error=${encodeURIComponent(error)}`);
  }

  try {
    await apiFetch(`/orders/${orderId}/status`, { method: "PATCH", body: { status, reason } });
  } catch (error) {
    failTo("/orders", error);
  }

  revalidatePath("/orders");
  redirect("/orders");
}

export async function saveRestaurant(_previous: SaveState, formData: FormData): Promise<SaveState> {
  const id = formData.get("id");
  const body = {
    name: formData.get("name"),
    description: formData.get("description") || null,
    address: formData.get("address"),
    delivery_fee_cents: centsFromInput(formData.get("delivery_fee")),
    is_open: formData.get("is_open") === "on",
  };

  try {
    const { data } = await apiFetch<Resource<Restaurant>>(id ? `/restaurants/${id}` : "/restaurants", {
      method: id ? "PATCH" : "POST",
      body,
    });

    if (!id) {
      revalidatePath("/", "layout");
      redirect(`/menu?r=${data.id}`);
    }
  } catch (error) {
    if (error instanceof ApiError) {
      const hasFieldErrors = Object.keys(error.fieldErrors).length > 0;
      return { error: hasFieldErrors ? undefined : error.message, fieldErrors: error.fieldErrors };
    }
    throw error;
  }

  revalidatePath("/restaurant");
  return { saved: true };
}

export async function createMenuItem(formData: FormData): Promise<void> {
  const restaurantId = Number(formData.get("restaurantId"));
  const back = `/menu?r=${restaurantId}`;

  try {
    await apiFetch(`/restaurants/${restaurantId}/menu-items`, {
      method: "POST",
      body: {
        name: formData.get("name"),
        description: formData.get("description") || null,
        price_cents: centsFromInput(formData.get("price")),
      },
    });
  } catch (error) {
    failTo(back, error);
  }

  revalidatePath("/menu");
  redirect(back);
}

export async function updateMenuItem(formData: FormData): Promise<void> {
  const id = Number(formData.get("id"));
  const back = `/menu?r=${Number(formData.get("restaurantId"))}`;

  try {
    await apiFetch(`/menu-items/${id}`, {
      method: "PATCH",
      body: {
        name: formData.get("name"),
        description: formData.get("description") || null,
        price_cents: centsFromInput(formData.get("price")),
      },
    });
  } catch (error) {
    failTo(back, error);
  }

  revalidatePath("/menu");
  redirect(back);
}

export async function toggleMenuItem(formData: FormData): Promise<void> {
  const id = Number(formData.get("id"));
  const back = `/menu?r=${Number(formData.get("restaurantId"))}`;

  try {
    await apiFetch(`/menu-items/${id}`, {
      method: "PATCH",
      body: { is_available: formData.get("is_available") === "true" },
    });
  } catch (error) {
    failTo(back, error);
  }

  revalidatePath("/menu");
  redirect(back);
}

export async function deleteMenuItem(formData: FormData): Promise<void> {
  const id = Number(formData.get("id"));
  const back = `/menu?r=${Number(formData.get("restaurantId"))}`;

  try {
    await apiFetch(`/menu-items/${id}`, { method: "DELETE" });
  } catch (error) {
    failTo(back, error);
  }

  revalidatePath("/menu");
  redirect(back);
}
