<?php

namespace App\Actions;

use App\Enums\OrderStatus;
use App\Models\MenuItem;
use App\Models\Order;
use App\Models\Restaurant;
use App\Models\User;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\ValidationException;

class PlaceOrder
{
    /**
     * Prices are always taken from the database, never from the request.
     *
     * @param  array{restaurant_id: int, delivery_address: string, notes?: string|null, payment_method?: string, items: list<array{menu_item_id: int, quantity: int}>}  $data
     */
    public function handle(User $customer, array $data): Order
    {
        $restaurant = Restaurant::with('owner')->findOrFail($data['restaurant_id']);

        if (! $restaurant->is_open || ! $restaurant->owner->isApproved()) {
            throw ValidationException::withMessages(['restaurant_id' => 'El restaurante no está disponible.']);
        }

        $quantities = $this->quantitiesByMenuItem($data['items']);

        $menuItems = MenuItem::query()
            ->where('restaurant_id', $restaurant->id)
            ->available()
            ->whereIn('id', array_keys($quantities))
            ->get();

        if ($menuItems->count() !== count($quantities)) {
            throw ValidationException::withMessages(['items' => 'Algún producto no existe o no está disponible en este restaurante.']);
        }

        $subtotal = $menuItems->sum(fn (MenuItem $item) => $item->price_cents * $quantities[$item->id]);

        return DB::transaction(function () use ($customer, $restaurant, $data, $menuItems, $quantities, $subtotal) {
            $order = new Order([
                'delivery_address' => $data['delivery_address'],
                'notes' => $data['notes'] ?? null,
                'payment_method' => $data['payment_method'] ?? 'cash',
            ]);

            $order->forceFill([
                'customer_id' => $customer->id,
                'restaurant_id' => $restaurant->id,
                'status' => OrderStatus::Pending,
                'subtotal_cents' => $subtotal,
                'delivery_fee_cents' => $restaurant->delivery_fee_cents,
                'total_cents' => $subtotal + $restaurant->delivery_fee_cents,
            ])->save();

            $order->items()->createMany(
                $menuItems->map(fn (MenuItem $item) => [
                    'menu_item_id' => $item->id,
                    'name' => $item->name,
                    'unit_price_cents' => $item->price_cents,
                    'quantity' => $quantities[$item->id],
                ])->all()
            );

            return $order->load(['restaurant', 'items']);
        });
    }

    /**
     * @param  list<array{menu_item_id: int, quantity: int}>  $items
     * @return array<int, int>
     */
    private function quantitiesByMenuItem(array $items): array
    {
        $quantities = [];

        foreach ($items as $item) {
            $id = (int) $item['menu_item_id'];
            $quantities[$id] = ($quantities[$id] ?? 0) + (int) $item['quantity'];
        }

        return $quantities;
    }
}
