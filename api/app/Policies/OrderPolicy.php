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

    /** A courier may give a claimed order back, but only before picking it up. */
    public function release(User $user, Order $order): bool
    {
        return $order->courier_id === $user->id
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
            OrderStatus::Preparing,
            OrderStatus::Ready,
            OrderStatus::Rejected => $order->restaurant->owner_id === $user->id,
            OrderStatus::PickedUp,
            OrderStatus::Delivered,
            OrderStatus::Failed => $order->courier_id === $user->id,
            OrderStatus::Cancelled => $this->canCancel($user, $order),
            OrderStatus::Pending => false,
        };
    }

    /**
     * The customer can cancel only while the restaurant has not answered. Once
     * the order is accepted, only the restaurant can call it off, and only
     * until a courier has the food.
     */
    private function canCancel(User $user, Order $order): bool
    {
        if ($order->customer_id === $user->id) {
            return $order->status === OrderStatus::Pending;
        }

        return $order->restaurant->owner_id === $user->id
            && in_array($order->status, [OrderStatus::Accepted, OrderStatus::Preparing, OrderStatus::Ready], true);
    }
}
