<?php

namespace App\Http\Resources;

use App\Models\User;
use Illuminate\Http\Request;

/**
 * A user as seen by themselves and by admins: includes the review status.
 *
 * @mixin User
 */
class AccountResource extends UserResource
{
    /**
     * @return array<string, mixed>
     */
    public function toArray(Request $request): array
    {
        return [
            ...parent::toArray($request),
            'status' => $this->status,
            'status_note' => $this->status_note,
            'created_at' => $this->created_at,
            'restaurants' => RestaurantResource::collection($this->whenLoaded('restaurants')),
        ];
    }
}
