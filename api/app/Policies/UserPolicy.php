<?php

namespace App\Policies;

use App\Enums\UserRole;
use App\Models\User;

class UserPolicy
{
    public function viewAny(User $user): bool
    {
        return $user->hasRole(UserRole::Admin);
    }

    /**
     * Admins review everyone except admins (including themselves), so nobody
     * can lock the platform out of its own administrators.
     */
    public function updateStatus(User $actor, User $target): bool
    {
        return $actor->hasRole(UserRole::Admin)
            && ! $target->hasRole(UserRole::Admin)
            && $actor->isNot($target);
    }
}
