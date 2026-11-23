import type { Metadata } from "next";
import { Photo } from "@/components/photo";
import { apiFetch } from "@/lib/api";
import { requireRestaurantOwner } from "@/lib/dal";
import type { Collection, Restaurant } from "@/lib/types";
import { removeRestaurantPhoto, uploadRestaurantPhoto } from "../actions";
import { PhotoUpload } from "../photo-upload";
import { RestaurantForm } from "./restaurant-form";

export const metadata: Metadata = { title: "Restaurante" };

export default async function RestaurantPage({ searchParams }: PageProps<"/restaurant">) {
  await requireRestaurantOwner({ allowPending: true });
  const { error } = await searchParams;
  const { data: restaurants } = await apiFetch<Collection<Restaurant>>("/owner/restaurants");
  const restaurant = restaurants[0];

  return (
    <div className="space-y-4">
      <h1 className="text-2xl font-semibold tracking-tight">{restaurant ? "Tu restaurante" : "Crea tu restaurante"}</h1>
      {!restaurant && <p className="text-sm text-zinc-500">Completa estos datos para empezar a recibir pedidos.</p>}

      {typeof error === "string" && (
        <p role="alert" className="max-w-xl rounded-lg bg-red-50 px-3 py-2 text-sm text-red-700 dark:bg-red-950 dark:text-red-300">
          {error}
        </p>
      )}

      {restaurant && (
        <section aria-labelledby="photo" className="max-w-xl space-y-3 rounded-xl border border-zinc-200 bg-white p-6 dark:border-zinc-800 dark:bg-zinc-950">
          <h2 id="photo" className="text-sm font-semibold">
            Foto de portada
          </h2>
          <Photo src={restaurant.image_url} alt={restaurant.name} className="aspect-[3/2] w-full rounded-lg" />
          <PhotoUpload
            label="Elige una foto"
            hiddenFields={{ restaurantId: restaurant.id }}
            hasPhoto={restaurant.image_url !== null}
            upload={uploadRestaurantPhoto}
            remove={removeRestaurantPhoto}
          />
        </section>
      )}

      <RestaurantForm key={restaurant?.id ?? "new"} restaurant={restaurant} />
    </div>
  );
}
