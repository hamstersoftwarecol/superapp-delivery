<?php

namespace App\Http\Resources;

use App\Models\Order;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/**
 * @mixin Order
 */
class OrderResource extends JsonResource
{
    /**
     * @return array<string, mixed>
     */
    public function toArray(Request $request): array
    {
        return [
            'id' => $this->id,
            'status' => $this->status,
            'subtotal_cents' => $this->subtotal_cents,
            'delivery_fee_cents' => $this->delivery_fee_cents,
            'total_cents' => $this->total_cents,
            'delivery_address' => $this->delivery_address,
            'notes' => $this->notes,
            'payment_method' => $this->payment_method,
            'status_reason' => $this->status_reason,
            'status_actor' => $this->status_actor,
            'status_changed_at' => $this->status_changed_at,
            'created_at' => $this->created_at,
            'restaurant' => new RestaurantResource($this->whenLoaded('restaurant')),
            'customer' => new UserResource($this->whenLoaded('customer')),
            'courier' => new UserResource($this->whenLoaded('courier')),
            'items' => OrderItemResource::collection($this->whenLoaded('items')),
        ];
    }
}
