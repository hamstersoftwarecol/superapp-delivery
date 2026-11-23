<?php

namespace App\Http\Controllers\Api\V1;

use App\Enums\OrderStatus;
use App\Http\Controllers\Controller;
use App\Http\Resources\OrderResource;
use App\Models\Order;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Gate;
use Symfony\Component\HttpKernel\Exception\ConflictHttpException;

/** A courier who cannot do the delivery after all gives the order back to the pool. */
class OrderReleaseController extends Controller
{
    public function __invoke(Request $request, Order $order): OrderResource
    {
        Gate::authorize('release', $order);

        // Conditional UPDATE: it only applies if this courier still holds a ready order.
        $released = Order::query()
            ->whereKey($order->id)
            ->where('courier_id', $request->user()->id)
            ->where('status', OrderStatus::Ready)
            ->update(['courier_id' => null, 'claimed_at' => null, 'available_at' => now()]);

        if ($released === 0) {
            throw new ConflictHttpException('Ya no puedes soltar este pedido.');
        }

        return new OrderResource($order->refresh()->load(['restaurant', 'customer', 'courier', 'items']));
    }
}
