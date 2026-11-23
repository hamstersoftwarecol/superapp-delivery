<?php

namespace Tests\Feature\Api\V1;

use App\Enums\OrderStatus;
use App\Models\MenuItem;
use App\Models\Order;
use App\Models\Restaurant;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class OrderFlowTest extends TestCase
{
    use RefreshDatabase;

    public function test_a_customer_places_an_order_and_the_server_computes_the_totals(): void
    {
        $restaurant = Restaurant::factory()->create(['delivery_fee_cents' => 300]);
        $taco = MenuItem::factory()->for($restaurant)->create(['price_cents' => 450]);
        $soda = MenuItem::factory()->for($restaurant)->create(['price_cents' => 200]);
        Sanctum::actingAs(User::factory()->create());

        $this->postJson('/api/v1/orders', [
            'restaurant_id' => $restaurant->id,
            'delivery_address' => 'Carrera 5 # 6-7',
            'items' => [
                ['menu_item_id' => $taco->id, 'quantity' => 2],
                ['menu_item_id' => $soda->id, 'quantity' => 1],
                ['menu_item_id' => $taco->id, 'quantity' => 1],
            ],
        ])->assertCreated()
            ->assertJsonPath('data.status', 'pending')
            ->assertJsonPath('data.subtotal_cents', 1550)
            ->assertJsonPath('data.delivery_fee_cents', 300)
            ->assertJsonPath('data.total_cents', 1850)
            ->assertJsonCount(2, 'data.items');
    }

    public function test_an_order_cannot_include_items_from_another_restaurant_or_unavailable_items(): void
    {
        $restaurant = Restaurant::factory()->create();
        $foreign = MenuItem::factory()->create();
        $unavailable = MenuItem::factory()->for($restaurant)->create(['is_available' => false]);
        Sanctum::actingAs(User::factory()->create());

        foreach ([$foreign, $unavailable] as $item) {
            $this->postJson('/api/v1/orders', [
                'restaurant_id' => $restaurant->id,
                'delivery_address' => 'Calle 1',
                'items' => [['menu_item_id' => $item->id, 'quantity' => 1]],
            ])->assertUnprocessable()->assertJsonValidationErrors('items');
        }

        $this->assertDatabaseCount('orders', 0);
    }

    public function test_an_order_cannot_be_placed_at_a_closed_restaurant(): void
    {
        $restaurant = Restaurant::factory()->create(['is_open' => false]);
        $item = MenuItem::factory()->for($restaurant)->create();
        Sanctum::actingAs(User::factory()->create());

        $this->postJson('/api/v1/orders', [
            'restaurant_id' => $restaurant->id,
            'delivery_address' => 'Calle 1',
            'items' => [['menu_item_id' => $item->id, 'quantity' => 1]],
        ])->assertUnprocessable()->assertJsonValidationErrors('restaurant_id');
    }

    public function test_only_customers_can_place_orders(): void
    {
        $restaurant = Restaurant::factory()->create();
        $item = MenuItem::factory()->for($restaurant)->create();
        Sanctum::actingAs(User::factory()->courier()->create());

        $this->postJson('/api/v1/orders', [
            'restaurant_id' => $restaurant->id,
            'delivery_address' => 'Calle 1',
            'items' => [['menu_item_id' => $item->id, 'quantity' => 1]],
        ])->assertForbidden();
    }

    public function test_the_full_delivery_flow_from_pending_to_delivered(): void
    {
        $order = Order::factory()->create();
        $owner = $order->restaurant->owner;
        $courier = User::factory()->courier()->create();

        Sanctum::actingAs($owner);
        foreach (['accepted', 'preparing', 'ready'] as $status) {
            $this->patchJson("/api/v1/orders/{$order->id}/status", ['status' => $status])
                ->assertOk()->assertJsonPath('data.status', $status);
        }

        Sanctum::actingAs($courier);
        $this->getJson('/api/v1/courier/available-orders')
            ->assertOk()->assertJsonCount(1, 'data');
        $this->postJson("/api/v1/orders/{$order->id}/claim")
            ->assertOk()->assertJsonPath('data.courier.id', $courier->id);
        $this->getJson('/api/v1/courier/available-orders')->assertJsonCount(0, 'data');

        foreach (['picked_up', 'delivered'] as $status) {
            $this->patchJson("/api/v1/orders/{$order->id}/status", ['status' => $status])
                ->assertOk()->assertJsonPath('data.status', $status);
        }

        $this->assertSame(OrderStatus::Delivered, $order->fresh()->status);
    }

    public function test_status_steps_cannot_be_skipped(): void
    {
        $order = Order::factory()->create();
        Sanctum::actingAs($order->restaurant->owner);

        $this->patchJson("/api/v1/orders/{$order->id}/status", ['status' => 'ready'])
            ->assertUnprocessable()->assertJsonValidationErrors('status');

        $this->assertSame(OrderStatus::Pending, $order->fresh()->status);
    }

    public function test_a_second_courier_cannot_claim_an_already_claimed_order(): void
    {
        $first = User::factory()->courier()->create();
        $order = Order::factory()->create(['status' => OrderStatus::Ready, 'courier_id' => $first->id]);

        Sanctum::actingAs(User::factory()->courier()->create());

        $this->postJson("/api/v1/orders/{$order->id}/claim")->assertForbidden();
        $this->assertSame($first->id, $order->fresh()->courier_id);
    }

    public function test_a_courier_cannot_claim_an_order_that_is_not_ready(): void
    {
        $order = Order::factory()->create(['status' => OrderStatus::Preparing]);
        Sanctum::actingAs(User::factory()->courier()->create());

        $this->postJson("/api/v1/orders/{$order->id}/claim")->assertForbidden();
    }

    public function test_a_customer_can_cancel_only_while_pending(): void
    {
        $pending = Order::factory()->create();
        Sanctum::actingAs($pending->customer);
        $this->patchJson("/api/v1/orders/{$pending->id}/status", ['status' => 'cancelled'])
            ->assertOk()->assertJsonPath('data.status', 'cancelled');

        $accepted = Order::factory()->create(['status' => OrderStatus::Accepted]);
        Sanctum::actingAs($accepted->customer);
        $this->patchJson("/api/v1/orders/{$accepted->id}/status", ['status' => 'cancelled'])
            ->assertForbidden();
    }

    public function test_a_customer_cannot_advance_their_own_order_like_a_restaurant(): void
    {
        $order = Order::factory()->create();
        Sanctum::actingAs($order->customer);

        $this->patchJson("/api/v1/orders/{$order->id}/status", ['status' => 'accepted'])
            ->assertForbidden();
    }

    public function test_users_only_see_their_own_orders(): void
    {
        $mine = Order::factory()->create();
        Order::factory()->create();

        Sanctum::actingAs($mine->customer);
        $this->getJson('/api/v1/orders')->assertOk()->assertJsonCount(1, 'data');
        $this->getJson("/api/v1/orders/{$mine->id}")->assertOk();

        Sanctum::actingAs($mine->restaurant->owner);
        $this->getJson('/api/v1/orders')->assertOk()->assertJsonCount(1, 'data');

        Sanctum::actingAs(User::factory()->create());
        $this->getJson("/api/v1/orders/{$mine->id}")->assertForbidden();
    }
}
