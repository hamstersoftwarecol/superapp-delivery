<?php

namespace App\Http\Controllers\Api\V1;

use App\Actions\PlaceOrder;
use App\Enums\OrderStatus;
use App\Enums\UserRole;
use App\Http\Controllers\Controller;
use App\Http\Requests\Api\V1\PlaceOrderRequest;
use App\Http\Resources\OrderResource;
use App\Models\Order;
use App\Models\User;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\AnonymousResourceCollection;
use Illuminate\Support\Facades\Gate;
use Illuminate\Validation\Rule;

class OrderController extends Controller
{
    public function index(Request $request): AnonymousResourceCollection
    {
        $filters = $request->validate([
            'status' => ['sometimes', Rule::enum(OrderStatus::class)],
        ]);

        $orders = $this->visibleTo($request->user())
            ->when($filters['status'] ?? null, fn (Builder $query, string $status) => $query->where('status', $status))
            ->with(['restaurant', 'customer', 'courier', 'items'])
            ->latest()
            ->paginate(20);

        return OrderResource::collection($orders);
    }

    public function store(PlaceOrderRequest $request, PlaceOrder $placeOrder): OrderResource
    {
        Gate::authorize('create', Order::class);

        return new OrderResource($placeOrder->handle($request->user(), $request->validated()));
    }

    public function show(Order $order): OrderResource
    {
        Gate::authorize('view', $order);

        return new OrderResource($order->load(['restaurant', 'customer', 'courier', 'items']));
    }

    /**
     * @return Builder<Order>
     */
    private function visibleTo(User $user): Builder
    {
        return match ($user->role) {
            UserRole::Customer => Order::query()->where('customer_id', $user->id),
            UserRole::Courier => Order::query()->where('courier_id', $user->id),
            UserRole::Restaurant => Order::query()->whereHas(
                'restaurant',
                fn (Builder $query) => $query->where('owner_id', $user->id)
            ),
        };
    }
}
