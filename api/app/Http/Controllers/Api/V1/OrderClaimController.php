<?php

namespace App\Http\Controllers\Api\V1;

use App\Enums\OrderStatus;
use App\Http\Controllers\Controller;
use App\Http\Resources\OrderResource;
use App\Models\Order;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Gate;
use Symfony\Component\HttpKernel\Exception\ConflictHttpException;

class OrderClaimController extends Controller
{
    public function __invoke(Request $request, Order $order): OrderResource
    {
        Gate::authorize('claim', $order);

        // Single conditional UPDATE so two couriers can never claim the same order.
        $claimed = Order::query()
            ->whereKey($order->id)
            ->whereNull('courier_id')
            ->where('status', OrderStatus::Ready)
            ->update(['courier_id' => $request->user()->id, 'claimed_at' => now()]);

        if ($claimed === 0) {
            throw new ConflictHttpException('Este pedido ya fue tomado por otro repartidor.');
        }

        return new OrderResource($order->refresh()->load(['restaurant', 'customer', 'courier', 'items']));
    }
}
