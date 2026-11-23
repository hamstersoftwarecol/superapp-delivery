<?php

namespace App\Policies;

use App\Enums\OrderStatus;
use App\Enums\UserRole;
use App\Models\Order;
use App\Models\User;

class OrderPolicy
{
    public function create(User $user): bool
    {
        return $user->hasRole(UserRole::Customer);
    }

    public function viewAvailable(User $user): bool
    {
        return $user->hasRole(UserRole::Courier);
    }

    public function view(User $user, Order $order): bool
    {
        return $order->customer_id === $user->id
            || $order->courier_id === $user->id
            || $order->restaurant->owner_id === $user->id;
    }

    public function claim(User $user, Order $order): bool
    {
        return $user->hasRole(UserRole::Courier)
            && $order->courier_id === null
            && $order->status === OrderStatus::Ready;
    }

    /**
     * Who may move an order to the given status. The state machine itself
     * (is this step legal from the current status?) lives in OrderStatus.
     */
    public function transition(User $user, Order $order, OrderStatus $next): bool
    {
        return match ($next) {
            OrderStatus::Accepted,
            OrderStatus::Rejected,
            OrderStatus::Preparing,
            OrderStatus::Ready => $order->restaurant->owner_id === $user->id,
            OrderStatus::PickedUp,
            OrderStatus::Delivered => $order->courier_id === $user->id,
            OrderStatus::Cancelled => $order->customer_id === $user->id
                && $order->status === OrderStatus::Pending,
            OrderStatus::Pending => false,
        };
    }
}
