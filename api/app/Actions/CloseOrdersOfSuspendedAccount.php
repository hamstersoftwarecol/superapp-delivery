<?php

namespace App\Actions;

use App\Enums\OrderActor;
use App\Enums\OrderStatus;
use App\Enums\UserRole;
use App\Models\Order;
use App\Models\User;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Support\Facades\DB;

/**
 * A suspended account cannot finish what it started, so its open orders are
 * closed (or handed back) instead of being left stuck forever.
 *
 * Orders a courier already picked up are never cancelled just because the
 * restaurant or customer was suspended: someone is carrying the food.
 */
class CloseOrdersOfSuspendedAccount
{
    /**
     * @return int How many orders were affected.
     */
    public function handle(User $user): int
    {
        return DB::transaction(fn () => match ($user->role) {
            UserRole::Restaurant => $this->cancel(
                Order::query()
                    ->whereHas('restaurant', fn (Builder $restaurant) => $restaurant->where('owner_id', $user->id))
                    ->whereIn('status', $this->beforePickup()),
                'El restaurante fue suspendido.',
            ),
            UserRole::Customer => $this->cancel(
                Order::query()->where('customer_id', $user->id)->whereIn('status', $this->beforePickup()),
                'La cuenta del cliente fue suspendida.',
            ),
            UserRole::Courier => $this->closeCourierOrders($user),
            UserRole::Admin => 0,
        });
    }

    private function closeCourierOrders(User $courier): int
    {
        $now = now();

        // Not picked up yet: back to the pool for another courier.
        $released = Order::query()
            ->where('courier_id', $courier->id)
            ->where('status', OrderStatus::Ready)
            ->update(['courier_id' => null, 'claimed_at' => null, 'available_at' => $now]);

        // Already carrying it: nobody knows where it is, so it is marked as not delivered.
        $failed = Order::query()
            ->where('courier_id', $courier->id)
            ->where('status', OrderStatus::PickedUp)
            ->update([
                'status' => OrderStatus::Failed->value,
                'status_reason' => 'El repartidor fue suspendido.',
                'status_actor' => OrderActor::System->value,
                'status_changed_at' => $now,
            ]);

        return $released + $failed;
    }

    /**
     * @param  Builder<Order>  $orders
     */
    private function cancel(Builder $orders, string $reason): int
    {
        return $orders->update([
            'status' => OrderStatus::Cancelled->value,
            'status_reason' => $reason,
            'status_actor' => OrderActor::System->value,
            'status_changed_at' => now(),
        ]);
    }

    /**
     * @return list<string>
     */
    private function beforePickup(): array
    {
        return collect(OrderStatus::cases())
            ->filter(fn (OrderStatus $status) => $status->isBeforePickup())
            ->map(fn (OrderStatus $status) => $status->value)
            ->values()
            ->all();
    }
}
