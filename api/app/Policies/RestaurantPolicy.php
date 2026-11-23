<?php

namespace App\Policies;

use App\Enums\UserRole;
use App\Models\Restaurant;
use App\Models\User;

class RestaurantPolicy
{
    public function create(User $user): bool
    {
        return $user->hasRole(UserRole::Restaurant);
    }

    public function update(User $user, Restaurant $restaurant): bool
    {
        return $restaurant->owner_id === $user->id;
    }
}
