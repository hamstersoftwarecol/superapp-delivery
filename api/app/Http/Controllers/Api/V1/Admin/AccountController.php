<?php

namespace App\Http\Controllers\Api\V1\Admin;

use App\Enums\AccountStatus;
use App\Enums\UserRole;
use App\Http\Controllers\Controller;
use App\Http\Resources\AccountResource;
use App\Models\User;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\AnonymousResourceCollection;
use Illuminate\Support\Facades\Gate;
use Illuminate\Validation\Rule;

class AccountController extends Controller
{
    public function index(Request $request): AnonymousResourceCollection
    {
        Gate::authorize('viewAny', User::class);

        $filters = $request->validate([
            'status' => ['sometimes', Rule::enum(AccountStatus::class)],
            'role' => ['sometimes', Rule::enum(UserRole::class)],
        ]);

        $accounts = User::query()
            ->whereNot('role', UserRole::Admin)
            ->when($filters['status'] ?? null, fn ($query, string $status) => $query->where('status', $status))
            ->when($filters['role'] ?? null, fn ($query, string $role) => $query->where('role', $role))
            ->with('restaurants')
            ->latest()
            ->paginate(50);

        return AccountResource::collection($accounts);
    }
}
