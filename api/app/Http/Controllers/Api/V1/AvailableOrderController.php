<?php

namespace App\Http\Controllers\Api\V1;

use App\Enums\OrderStatus;
use App\Http\Controllers\Controller;
use App\Http\Resources\OrderResource;
use App\Models\Order;
use Illuminate\Http\Resources\Json\AnonymousResourceCollection;
use Illuminate\Support\Facades\Gate;

class AvailableOrderController extends Controller
{
    public function __invoke(): AnonymousResourceCollection
    {
        Gate::authorize('viewAvailable', Order::class);

        $orders = Order::query()
            ->where('status', OrderStatus::Ready)
            ->whereNull('courier_id')
            ->with(['restaurant', 'items'])
            ->oldest()
            ->paginate(20);

        return OrderResource::collection($orders);
    }
}
