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
    /**
     * `?scope=active` returns every order still in progress (up to 100, no
     * pages) so none can hide behind page two. `?scope=history` and no scope
     * return pages of 20 using a cursor, which stays correct while new orders
     * keep arriving.
     */
    public function index(Request $request): AnonymousResourceCollection
    {
        $filters = $request->validate([
            'status' => ['sometimes', Rule::enum(OrderStatus::class)],
            'scope' => ['sometimes', Rule::in(['active', 'history'])],
        ]);

        $orders = $this->visibleTo($request->user())
            ->when($filters['status'] ?? null, fn (Builder $query, string $status) => $query->where('status', $status))
            ->when(($filters['scope'] ?? null) === 'active', fn (Builder $query) => $query->whereIn('status', $this->statuses(final: false)))
            ->when(($filters['scope'] ?? null) === 'history', fn (Builder $query) => $query->whereIn('status', $this->statuses(final: true)))
            ->with(['restaurant', 'customer', 'courier', 'items'])
            ->orderByDesc('created_at')
            ->orderByDesc('id');

        return OrderResource::collection(
            ($filters['scope'] ?? null) === 'active' ? $orders->limit(100)->get() : $orders->cursorPaginate(20)
        );
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
     * @return list<string>
     */
    private function statuses(bool $final): array
    {
        return collect(OrderStatus::cases())
            ->filter(fn (OrderStatus $status) => $status->isFinal() === $final)
            ->map(fn (OrderStatus $status) => $status->value)
            ->values()
            ->all();
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
