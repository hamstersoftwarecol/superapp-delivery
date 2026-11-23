<?php

namespace App\Http\Controllers\Api\V1\Admin;

use App\Enums\AccountStatus;
use App\Http\Controllers\Controller;
use App\Http\Requests\Api\V1\Admin\UpdateAccountStatusRequest;
use App\Http\Resources\AccountResource;
use App\Models\User;
use Illuminate\Support\Facades\Gate;

class AccountStatusController extends Controller
{
    public function __invoke(UpdateAccountStatusRequest $request, User $user): AccountResource
    {
        Gate::authorize('updateStatus', $user);

        $status = AccountStatus::from($request->validated('status'));

        $user->forceFill([
            'status' => $status,
            // A note explains a refusal; an approval needs none.
            'status_note' => $status === AccountStatus::Suspended ? $request->validated('note') : null,
        ])->save();

        if ($status === AccountStatus::Suspended) {
            $user->tokens()->delete();
        }

        return new AccountResource($user->load('restaurants'));
    }
}
