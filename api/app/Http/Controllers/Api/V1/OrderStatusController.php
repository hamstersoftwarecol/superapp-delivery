<?php

namespace App\Http\Controllers\Api\V1;

use App\Actions\TransitionOrder;
use App\Http\Controllers\Controller;
use App\Http\Requests\Api\V1\UpdateOrderStatusRequest;
use App\Http\Resources\OrderResource;
use App\Models\Order;
use Illuminate\Support\Facades\Gate;

class OrderStatusController extends Controller
{
    public function __invoke(UpdateOrderStatusRequest $request, Order $order, TransitionOrder $transitionOrder): OrderResource
    {
        $next = $request->status();

        Gate::authorize('transition', [$order, $next]);

        $updated = $transitionOrder->handle($order, $next);

        return new OrderResource($updated->load(['restaurant', 'customer', 'courier', 'items']));
    }
}
