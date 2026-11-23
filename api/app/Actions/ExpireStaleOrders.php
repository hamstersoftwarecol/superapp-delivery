<?php

namespace App\Actions;

use App\Enums\OrderActor;
use App\Enums\OrderStatus;
use App\Models\Order;
use Carbon\CarbonInterface;
use Illuminate\Database\Eloquent\Builder;

/**
 * Steps in when nobody acts on an order for too long (see config/delivery.php).
 *
 * Every rule is one conditional UPDATE, so it is safe to run while people are
 * using the app: an order someone just accepted or claimed is left alone.
 */
class ExpireStaleOrders
{
    /**
     * @return array{cancelled_pending: int, cancelled_unclaimed: int, released: int}
     */
    public function handle(?CarbonInterface $now = null): array
    {
        $now ??= now();

        // First give back orders a courier took and never picked up, so they
        // get a fresh window before the "no courier available" rule below.
        $released = Order::query()
            ->where('status', OrderStatus::Ready)
            ->whereNotNull('courier_id')
            ->where('claimed_at', '<=', $now->copy()->subMinutes(config('delivery.claim_timeout_minutes')))
            ->update(['courier_id' => null, 'claimed_at' => null, 'available_at' => $now]);

        $cancelledUnclaimed = $this->cancel(
            Order::query()
                ->where('status', OrderStatus::Ready)
                ->whereNull('courier_id')
                ->where('available_at', '<=', $now->copy()->subMinutes(config('delivery.unclaimed_timeout_minutes'))),
            'No hubo un repartidor disponible a tiempo.',
            $now,
        );

        $cancelledPending = $this->cancel(
            Order::query()
                ->where('status', OrderStatus::Pending)
                ->where('status_changed_at', '<=', $now->copy()->subMinutes(config('delivery.pending_timeout_minutes'))),
            'El restaurante no respondió a tiempo.',
            $now,
        );

        return [
            'cancelled_pending' => $cancelledPending,
            'cancelled_unclaimed' => $cancelledUnclaimed,
            'released' => $released,
        ];
    }

    /**
     * @param  Builder<Order>  $orders
     */
    private function cancel($orders, string $reason, CarbonInterface $now): int
    {
        return $orders->update([
            'status' => OrderStatus::Cancelled->value,
            'status_reason' => $reason,
            'status_actor' => OrderActor::System->value,
            'status_changed_at' => $now,
        ]);
    }
}
