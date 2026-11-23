<?php

namespace Database\Factories;

use App\Enums\OrderStatus;
use App\Models\Order;
use App\Models\Restaurant;
use App\Models\User;
use Illuminate\Database\Eloquent\Factories\Factory;

/**
 * @extends Factory<Order>
 */
class OrderFactory extends Factory
{
    /**
     * Define the model's default state.
     *
     * @return array<string, mixed>
     */
    public function definition(): array
    {
        return [
            'customer_id' => User::factory(),
            'restaurant_id' => Restaurant::factory(),
            'courier_id' => null,
            'status' => OrderStatus::Pending,
            'subtotal_cents' => 1000,
            'delivery_fee_cents' => 200,
            'total_cents' => 1200,
            'delivery_address' => fake()->address(),
            'notes' => null,
            'payment_method' => 'cash',
        ];
    }
}
