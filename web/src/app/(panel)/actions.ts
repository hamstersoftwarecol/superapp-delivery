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
    // For validation errors the useful text is the first field message.
    const message = Object.values(error.fieldErrors)[0]?.[0] ?? error.message;
    const separator = path.includes("?") ? "&" : "?";
    redirect(`${path}${separator}error=${encodeURIComponent(message)}`);
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

/** Rebuilds the upload as a clean multipart body for the API. */
function photoBody(formData: FormData): FormData | null {
  const file = formData.get("image");

  if (!(file instanceof File) || file.size === 0) {
    return null;
  }

  const body = new FormData();
  body.set("image", file, file.name);

  return body;
}

export async function uploadRestaurantPhoto(formData: FormData): Promise<void> {
  const id = Number(formData.get("restaurantId"));
  const body = photoBody(formData);

  if (!body) {
    redirect(`/restaurant?error=${encodeURIComponent("Elige una imagen.")}`);
  }

  try {
    await apiFetch(`/restaurants/${id}/image`, { method: "POST", body });
  } catch (error) {
    failTo("/restaurant", error);
  }

  revalidatePath("/restaurant");
  revalidatePath("/menu");
  redirect("/restaurant");
}

export async function removeRestaurantPhoto(formData: FormData): Promise<void> {
  const id = Number(formData.get("restaurantId"));

  try {
    await apiFetch(`/restaurants/${id}/image`, { method: "DELETE" });
  } catch (error) {
    failTo("/restaurant", error);
  }

  revalidatePath("/restaurant");
  revalidatePath("/menu");
  redirect("/restaurant");
}

export async function uploadMenuItemPhoto(formData: FormData): Promise<void> {
  const id = Number(formData.get("id"));
  const back = `/menu?r=${Number(formData.get("restaurantId"))}`;
  const body = photoBody(formData);

  if (!body) {
    redirect(`${back}&error=${encodeURIComponent("Elige una imagen.")}`);
  }

  try {
    await apiFetch(`/menu-items/${id}/image`, { method: "POST", body });
  } catch (error) {
    failTo(back, error);
  }

  revalidatePath("/menu");
  redirect(back);
}

export async function removeMenuItemPhoto(formData: FormData): Promise<void> {
  const id = Number(formData.get("id"));
  const back = `/menu?r=${Number(formData.get("restaurantId"))}`;

  try {
    await apiFetch(`/menu-items/${id}/image`, { method: "DELETE" });
  } catch (error) {
    failTo(back, error);
  }

  revalidatePath("/menu");
  redirect(back);
}
