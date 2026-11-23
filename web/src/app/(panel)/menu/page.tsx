import type { Metadata } from "next";
import Link from "next/link";
import { Field } from "@/components/field";
import { SubmitButton } from "@/components/submit-button";
import { apiFetch } from "@/lib/api";
import { requireRestaurantOwner } from "@/lib/dal";
import { formatCents, inputFromCents } from "@/lib/format";
import type { Collection, MenuItem, Restaurant } from "@/lib/types";
import { createMenuItem, deleteMenuItem, toggleMenuItem, updateMenuItem } from "../actions";

export const metadata: Metadata = { title: "Menú" };

export default async function MenuPage({ searchParams }: PageProps<"/menu">) {
  await requireRestaurantOwner({ allowPending: true });
  const { r, error } = await searchParams;
  const { data: restaurants } = await apiFetch<Collection<Restaurant>>("/owner/restaurants");

  if (restaurants.length === 0) {
    return (
      <div className="rounded-xl border border-dashed border-zinc-300 p-10 text-center dark:border-zinc-800">
        <h1 className="text-lg font-semibold">Primero crea tu restaurante</h1>
        <p className="mt-1 text-sm text-zinc-500">Necesitas un restaurante para poder agregar productos al menú.</p>
        <Link href="/restaurant" className="mt-4 inline-block rounded-lg bg-orange-600 px-4 py-2 text-sm font-medium text-white hover:bg-orange-700">
          Crear restaurante
        </Link>
      </div>
    );
  }

  const selected = restaurants.find((restaurant) => String(restaurant.id) === r) ?? restaurants[0];
  const items: MenuItem[] = selected.menu_items ?? [];

  return (
    <div className="space-y-6">
      <div className="flex flex-wrap items-center justify-between gap-3">
        <h1 className="text-2xl font-semibold tracking-tight">Menú de {selected.name}</h1>
        {restaurants.length > 1 && (
          <nav aria-label="Restaurantes" className="flex gap-2">
            {restaurants.map((restaurant) => (
              <Link
                key={restaurant.id}
                href={`/menu?r=${restaurant.id}`}
                aria-current={restaurant.id === selected.id ? "page" : undefined}
                className={`rounded-lg px-3 py-1.5 text-sm ${restaurant.id === selected.id ? "bg-orange-600 text-white" : "border border-zinc-300 dark:border-zinc-700"}`}
              >
                {restaurant.name}
              </Link>
            ))}
          </nav>
        )}
      </div>

      {typeof error === "string" && (
        <p role="alert" className="rounded-lg bg-red-50 px-3 py-2 text-sm text-red-700 dark:bg-red-950 dark:text-red-300">
          {error}
        </p>
      )}

      <form action={createMenuItem} className="grid gap-3 rounded-xl border border-zinc-200 bg-white p-4 sm:grid-cols-[2fr_3fr_1fr_auto] sm:items-end dark:border-zinc-800 dark:bg-zinc-950">
        <input type="hidden" name="restaurantId" value={selected.id} />
        <Field label="Producto" name="name" required placeholder="Taco al pastor" />
        <Field label="Descripción" name="description" placeholder="Opcional" />
        <Field label="Precio" name="price" type="number" step="0.01" min="0.01" required placeholder="4500" />
        <SubmitButton>Agregar</SubmitButton>
      </form>

      {items.length === 0 ? (
        <p className="rounded-xl border border-dashed border-zinc-300 p-8 text-center text-sm text-zinc-500 dark:border-zinc-800">
          Aún no tienes productos. Agrega el primero arriba.
        </p>
      ) : (
        <ul className="divide-y divide-zinc-200 rounded-xl border border-zinc-200 bg-white dark:divide-zinc-800 dark:border-zinc-800 dark:bg-zinc-950">
          {items.map((item) => (
            <li key={item.id} className="p-4">
              <div className="flex flex-wrap items-center justify-between gap-3">
                <div className={item.is_available ? "" : "opacity-50"}>
                  <p className="font-medium">{item.name}</p>
                  {item.description && <p className="text-sm text-zinc-500">{item.description}</p>}
                </div>
                <div className="flex items-center gap-2">
                  <span className="tabular-nums font-medium">{formatCents(item.price_cents)}</span>
                  <form action={toggleMenuItem}>
                    <input type="hidden" name="id" value={item.id} />
                    <input type="hidden" name="restaurantId" value={selected.id} />
                    <input type="hidden" name="is_available" value={String(!item.is_available)} />
                    <SubmitButton variant="secondary">{item.is_available ? "Disponible" : "Agotado"}</SubmitButton>
                  </form>
                  <form action={deleteMenuItem}>
                    <input type="hidden" name="id" value={item.id} />
                    <input type="hidden" name="restaurantId" value={selected.id} />
                    <SubmitButton variant="danger">Eliminar</SubmitButton>
                  </form>
                </div>
              </div>
              <details className="mt-2">
                <summary className="cursor-pointer text-sm text-orange-700 dark:text-orange-400">Editar</summary>
                <form action={updateMenuItem} className="mt-3 grid gap-3 sm:grid-cols-[2fr_3fr_1fr_auto] sm:items-end">
                  <input type="hidden" name="id" value={item.id} />
                  <input type="hidden" name="restaurantId" value={selected.id} />
                  <Field label="Producto" name="name" id={`name-${item.id}`} defaultValue={item.name} required />
                  <Field label="Descripción" name="description" id={`description-${item.id}`} defaultValue={item.description ?? ""} />
                  <Field label="Precio" name="price" id={`price-${item.id}`} type="number" step="0.01" min="0.01" defaultValue={inputFromCents(item.price_cents)} required />
                  <SubmitButton>Guardar</SubmitButton>
                </form>
              </details>
            </li>
          ))}
        </ul>
      )}
    </div>
  );
}
