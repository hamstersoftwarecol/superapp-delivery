<?php

namespace Tests\Feature\Orders;

use App\Enums\OrderStatus;
use App\Models\Order;
use App\Models\Restaurant;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class SuspensionClosesOrdersTest extends TestCase
{
    use RefreshDatabase;

    private function suspend(User $user): void
    {
        Sanctum::actingAs(User::factory()->admin()->create());

        $this->patchJson("/api/v1/admin/accounts/{$user->id}/status", ['status' => 'suspended', 'note' => 'Prueba'])->assertOk();
    }

    public function test_suspending_a_restaurant_cancels_the_orders_nobody_has_picked_up(): void
    {
        $restaurant = Restaurant::factory()->create();
        $courier = User::factory()->courier()->create();
        $open = collect(['pending', 'accepted', 'preparing', 'ready'])
            ->map(fn (string $status) => Order::factory()->for($restaurant)->create(['status' => OrderStatus::from($status)]));
        $onTheWay = Order::factory()->for($restaurant)->create(['status' => OrderStatus::PickedUp, 'courier_id' => $courier->id]);
        $delivered = Order::factory()->for($restaurant)->create(['status' => OrderStatus::Delivered, 'courier_id' => $courier->id]);
        $other = Order::factory()->create();

        $this->suspend($restaurant->owner);

        foreach ($open as $order) {
            $order->refresh();
            $this->assertSame(OrderStatus::Cancelled, $order->status);
            $this->assertSame('El restaurante fue suspendido.', $order->status_reason);
            $this->assertSame('system', $order->status_actor->value);
        }
        $this->assertSame(OrderStatus::PickedUp, $onTheWay->fresh()->status, 'someone is carrying the food');
        $this->assertSame(OrderStatus::Delivered, $delivered->fresh()->status);
        $this->assertSame(OrderStatus::Pending, $other->fresh()->status);
    }

    public function test_suspending_a_courier_releases_ready_orders_and_fails_the_ones_in_transit(): void
    {
        $courier = User::factory()->courier()->create();
        $ready = Order::factory()->create(['status' => OrderStatus::Ready, 'courier_id' => $courier->id, 'claimed_at' => now()]);
        $inTransit = Order::factory()->create(['status' => OrderStatus::PickedUp, 'courier_id' => $courier->id]);
        $delivered = Order::factory()->create(['status' => OrderStatus::Delivered, 'courier_id' => $courier->id]);

        $this->suspend($courier);

        $ready->refresh();
        $this->assertNull($ready->courier_id);
        $this->assertSame(OrderStatus::Ready, $ready->status);
        $this->assertNotNull($ready->available_at);

        $inTransit->refresh();
        $this->assertSame(OrderStatus::Failed, $inTransit->status);
        $this->assertSame('El repartidor fue suspendido.', $inTransit->status_reason);

        $this->assertSame(OrderStatus::Delivered, $delivered->fresh()->status);
    }

    public function test_suspending_a_customer_cancels_their_open_orders(): void
    {
        $customer = User::factory()->create();
        $pending = Order::factory()->for($customer, 'customer')->create();
        $preparing = Order::factory()->for($customer, 'customer')->create(['status' => OrderStatus::Preparing]);
        $others = Order::factory()->create();

        $this->suspend($customer);

        $this->assertSame(OrderStatus::Cancelled, $pending->fresh()->status);
        $this->assertSame(OrderStatus::Cancelled, $preparing->fresh()->status);
        $this->assertSame('La cuenta del cliente fue suspendida.', $pending->fresh()->status_reason);
        $this->assertSame(OrderStatus::Pending, $others->fresh()->status);
    }

    public function test_reactivating_an_account_does_not_bring_cancelled_orders_back(): void
    {
        $restaurant = Restaurant::factory()->create();
        $order = Order::factory()->for($restaurant)->create();
        $this->suspend($restaurant->owner);

        $this->patchJson("/api/v1/admin/accounts/{$restaurant->owner->id}/status", ['status' => 'approved'])->assertOk();

        $this->assertSame(OrderStatus::Cancelled, $order->fresh()->status);
    }

    public function test_approving_never_touches_orders(): void
    {
        $courier = User::factory()->courier()->pending()->create();
        $order = Order::factory()->create(['status' => OrderStatus::Ready]);
        Sanctum::actingAs(User::factory()->admin()->create());

        $this->patchJson("/api/v1/admin/accounts/{$courier->id}/status", ['status' => 'approved'])->assertOk();

        $this->assertSame(OrderStatus::Ready, $order->fresh()->status);
    }
}
