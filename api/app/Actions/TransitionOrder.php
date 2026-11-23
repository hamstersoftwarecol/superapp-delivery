<?php

namespace App\Actions;

use App\Enums\OrderStatus;
use App\Models\Order;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\ValidationException;

class TransitionOrder
{
    public function handle(Order $order, OrderStatus $next): Order
    {
        return DB::transaction(function () use ($order, $next) {
            $locked = Order::query()->lockForUpdate()->findOrFail($order->id);

            if (! $locked->status->canTransitionTo($next)) {
                throw ValidationException::withMessages([
                    'status' => "No se puede pasar de {$locked->status->value} a {$next->value}.",
                ]);
            }

            $locked->forceFill(['status' => $next])->save();

            return $locked;
        });
    }
}
