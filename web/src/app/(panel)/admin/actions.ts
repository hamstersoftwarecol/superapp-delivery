"use server";

import { revalidatePath } from "next/cache";
import { redirect } from "next/navigation";
import { ApiError, apiFetch } from "@/lib/api";

const STATUSES = ["approved", "suspended"] as const;

export async function setAccountStatus(formData: FormData): Promise<void> {
  const id = Number(formData.get("id"));
  const status = String(formData.get("status"));
  const note = String(formData.get("note") ?? "").trim();
  const back = String(formData.get("back") ?? "/admin");

  if (!Number.isInteger(id) || !STATUSES.includes(status as (typeof STATUSES)[number])) {
    redirect(back);
  }

  try {
    await apiFetch(`/admin/accounts/${id}/status`, {
      method: "PATCH",
      body: { status, note: note || null },
    });
  } catch (error) {
    if (error instanceof ApiError) {
      const separator = back.includes("?") ? "&" : "?";
      redirect(`${back}${separator}error=${encodeURIComponent(error.message)}`);
    }
    throw error;
  }

  revalidatePath("/admin");
  redirect(back);
}
