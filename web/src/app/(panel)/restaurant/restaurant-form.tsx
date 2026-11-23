"use client";

import { useActionState } from "react";
import { Field } from "@/components/field";
import { SubmitButton } from "@/components/submit-button";
import { inputFromCents } from "@/lib/format";
import type { Restaurant } from "@/lib/types";
import { saveRestaurant } from "../actions";

export function RestaurantForm({ restaurant }: { restaurant?: Restaurant }) {
  const [state, action] = useActionState(saveRestaurant, undefined);

  return (
    <form action={action} className="max-w-xl space-y-4 rounded-xl border border-zinc-200 bg-white p-6 dark:border-zinc-800 dark:bg-zinc-950">
      {restaurant && <input type="hidden" name="id" value={restaurant.id} />}

      {state?.error && (
        <p role="alert" className="rounded-lg bg-red-50 px-3 py-2 text-sm text-red-700 dark:bg-red-950 dark:text-red-300">
          {state.error}
        </p>
      )}
      {state?.saved && (
        <p role="status" className="rounded-lg bg-green-50 px-3 py-2 text-sm text-green-700 dark:bg-green-950 dark:text-green-300">
          Cambios guardados.
        </p>
      )}

      <Field label="Nombre" name="name" defaultValue={restaurant?.name} required errors={state?.fieldErrors?.name} />
      <Field label="Descripción" name="description" multiline defaultValue={restaurant?.description ?? ""} errors={state?.fieldErrors?.description} />
      <Field label="Dirección" name="address" defaultValue={restaurant?.address} required errors={state?.fieldErrors?.address} />
      <Field
        label="Costo de envío"
        name="delivery_fee"
        type="number"
        step="0.01"
        min="0"
        defaultValue={restaurant ? inputFromCents(restaurant.delivery_fee_cents) : 0}
        errors={state?.fieldErrors?.delivery_fee_cents}
      />

      <label className="flex items-center gap-3 text-sm">
        <input type="checkbox" name="is_open" defaultChecked={restaurant?.is_open ?? true} className="size-4 accent-orange-600" />
        Abierto y recibiendo pedidos
      </label>

      <SubmitButton>{restaurant ? "Guardar cambios" : "Crear restaurante"}</SubmitButton>
    </form>
  );
}
