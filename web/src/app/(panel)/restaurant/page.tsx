import type { Metadata } from "next";
import { apiFetch } from "@/lib/api";
import { getCurrentUser } from "@/lib/dal";
import type { Collection, Restaurant } from "@/lib/types";
import { RestaurantForm } from "./restaurant-form";

export const metadata: Metadata = { title: "Restaurante" };

export default async function RestaurantPage() {
  await getCurrentUser();
  const { data: restaurants } = await apiFetch<Collection<Restaurant>>("/owner/restaurants");
  const restaurant = restaurants[0];

  return (
    <div className="space-y-4">
      <h1 className="text-2xl font-semibold tracking-tight">{restaurant ? "Tu restaurante" : "Crea tu restaurante"}</h1>
      {!restaurant && (
        <p className="text-sm text-zinc-500">Completa estos datos para empezar a recibir pedidos.</p>
      )}
      <RestaurantForm key={restaurant?.id ?? "new"} restaurant={restaurant} />
    </div>
  );
}
