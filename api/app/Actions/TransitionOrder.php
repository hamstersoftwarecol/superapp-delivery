<?php

namespace App\Actions;

use App\Enums\OrderActor;
use App\Enums\OrderStatus;
use App\Models\Order;
use App\Models\User;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\ValidationException;

class TransitionOrder
{
    /**
     * @param  User|null  $actor  Who is doing it; `null` means the platform itself.
     * @param  string|null  $reason  Shown to the other parties when the order ends badly.
     */
    public function handle(Order $order, OrderStatus $next, ?User $actor = null, ?string $reason = null): Order
    {
        return DB::transaction(function () use ($order, $next, $actor, $reason) {
            $locked = Order::query()->lockForUpdate()->findOrFail($order->id);

            if (! $locked->status->canTransitionTo($next)) {
                throw ValidationException::withMessages([
                    'status' => "No se puede pasar de {$locked->status->value} a {$next->value}.",
                ]);
            }

            $locked->forceFill([
                'status' => $next,
                'status_reason' => $next->needsReason() ? $reason : null,
                'status_actor' => OrderActor::forRole($actor?->role),
            ])->save();

            return $locked;
        });
    }
}
