<?php

namespace Tests\Feature\Api\V1;

use App\Enums\OrderActor;
use App\Enums\OrderStatus;
use App\Models\Order;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class OrderFailureRulesTest extends TestCase
{
    use RefreshDatabase;

    private function setStatus(string $status, ?User $courier = null): Order
    {
        return Order::factory()->create([
            'status' => OrderStatus::from($status),
            'courier_id' => $courier?->id,
            'claimed_at' => $courier ? now() : null,
        ]);
    }

    public function test_the_restaurant_must_explain_a_rejection(): void
    {
        $order = Order::factory()->create();
        Sanctum::actingAs($order->restaurant->owner);

        $this->patchJson("/api/v1/orders/{$order->id}/status", ['status' => 'rejected'])
            ->assertUnprocessable()
            ->assertJsonValidationErrors('reason');

        $this->assertSame(OrderStatus::Pending, $order->fresh()->status);
    }

    public function test_a_rejection_records_who_and_why_and_the_customer_can_see_it(): void
    {
        $order = Order::factory()->create();
        Sanctum::actingAs($order->restaurant->owner);

        $this->patchJson("/api/v1/orders/{$order->id}/status", ['status' => 'rejected', 'reason' => '  Sin ingredientes  '])
            ->assertOk()
            ->assertJsonPath('data.status_reason', 'Sin ingredientes')
            ->assertJsonPath('data.status_actor', 'restaurant');

        Sanctum::actingAs($order->customer);
        $this->getJson("/api/v1/orders/{$order->id}")
            ->assertOk()
            ->assertJsonPath('data.status', 'rejected')
            ->assertJsonPath('data.status_reason', 'Sin ingredientes');
    }

    public function test_a_restaurant_can_cancel_an_order_it_already_accepted_until_a_courier_has_it(): void
    {
        foreach (['accepted', 'preparing', 'ready'] as $status) {
            $order = $this->setStatus($status);
            Sanctum::actingAs($order->restaurant->owner);

            $this->patchJson("/api/v1/orders/{$order->id}/status", ['status' => 'cancelled', 'reason' => 'Se dañó el horno'])
                ->assertOk()
                ->assertJsonPath('data.status', 'cancelled')
                ->assertJsonPath('data.status_actor', 'restaurant');
        }
    }

    public function test_a_restaurant_must_say_why_it_cancels(): void
    {
        $order = $this->setStatus('preparing');
        Sanctum::actingAs($order->restaurant->owner);

        $this->patchJson("/api/v1/orders/{$order->id}/status", ['status' => 'cancelled'])
            ->assertUnprocessable()
            ->assertJsonValidationErrors('reason');
    }

    public function test_a_restaurant_cannot_cancel_once_the_courier_picked_the_order_up(): void
    {
        $order = $this->setStatus('picked_up', User::factory()->courier()->create());
        Sanctum::actingAs($order->restaurant->owner);

        $this->patchJson("/api/v1/orders/{$order->id}/status", ['status' => 'cancelled', 'reason' => 'Ya no'])
            ->assertForbidden();

        $this->assertSame(OrderStatus::PickedUp, $order->fresh()->status);
    }

    public function test_a_customer_cancels_a_pending_order_without_giving_a_reason(): void
    {
        $order = Order::factory()->create();
        Sanctum::actingAs($order->customer);

        $this->patchJson("/api/v1/orders/{$order->id}/status", ['status' => 'cancelled'])
            ->assertOk()
            ->assertJsonPath('data.status_actor', 'customer')
            ->assertJsonPath('data.status_reason', null);
    }

    public function test_a_customer_cannot_cancel_after_the_restaurant_accepted(): void
    {
        $order = $this->setStatus('accepted');
        Sanctum::actingAs($order->customer);

        $this->patchJson("/api/v1/orders/{$order->id}/status", ['status' => 'cancelled'])->assertForbidden();
    }

    public function test_the_courier_reports_a_failed_delivery_with_a_reason(): void
    {
        $courier = User::factory()->courier()->create();
        $order = $this->setStatus('picked_up', $courier);
        Sanctum::actingAs($courier);

        $this->patchJson("/api/v1/orders/{$order->id}/status", ['status' => 'failed'])
            ->assertUnprocessable()
            ->assertJsonValidationErrors('reason');

        $this->patchJson("/api/v1/orders/{$order->id}/status", ['status' => 'failed', 'reason' => 'El cliente no contestó'])
            ->assertOk()
            ->assertJsonPath('data.status', 'failed')
            ->assertJsonPath('data.status_reason', 'El cliente no contestó')
            ->assertJsonPath('data.status_actor', 'courier');
    }

    public function test_a_delivery_can_only_fail_after_pickup_and_only_by_its_courier(): void
    {
        $courier = User::factory()->courier()->create();
        $ready = $this->setStatus('ready', $courier);
        $pickedUp = $this->setStatus('picked_up', User::factory()->courier()->create());

        Sanctum::actingAs($courier);
        $this->patchJson("/api/v1/orders/{$ready->id}/status", ['status' => 'failed', 'reason' => 'x'])
            ->assertUnprocessable();
        $this->patchJson("/api/v1/orders/{$pickedUp->id}/status", ['status' => 'failed', 'reason' => 'x'])
            ->assertForbidden();
    }

    public function test_final_statuses_cannot_be_changed_again(): void
    {
        foreach (['delivered', 'rejected', 'cancelled', 'failed'] as $status) {
            $courier = User::factory()->courier()->create();
            $order = $this->setStatus($status, $courier);
            Sanctum::actingAs($order->restaurant->owner);

            $this->patchJson("/api/v1/orders/{$order->id}/status", ['status' => 'accepted'])->assertUnprocessable();
        }
    }

    public function test_the_reason_is_dropped_when_the_order_does_not_end_badly(): void
    {
        $order = Order::factory()->create();
        Sanctum::actingAs($order->restaurant->owner);

        $this->patchJson("/api/v1/orders/{$order->id}/status", ['status' => 'accepted', 'reason' => 'ignorado'])
            ->assertOk()
            ->assertJsonPath('data.status_reason', null);
    }

    public function test_a_courier_can_give_back_an_order_before_picking_it_up(): void
    {
        $courier = User::factory()->courier()->create();
        $order = $this->setStatus('ready', $courier);
        Sanctum::actingAs($courier);

        $this->postJson("/api/v1/orders/{$order->id}/release")
            ->assertOk()
            ->assertJsonPath('data.courier', null);

        $order->refresh();
        $this->assertNull($order->courier_id);
        $this->assertNull($order->claimed_at);

        $this->getJson('/api/v1/courier/available-orders')->assertJsonCount(1, 'data');
    }

    public function test_another_courier_can_take_a_released_order(): void
    {
        $first = User::factory()->courier()->create();
        $order = $this->setStatus('ready', $first);
        Sanctum::actingAs($first);
        $this->postJson("/api/v1/orders/{$order->id}/release")->assertOk();

        $second = User::factory()->courier()->create();
        Sanctum::actingAs($second);
        $this->postJson("/api/v1/orders/{$order->id}/claim")
            ->assertOk()
            ->assertJsonPath('data.courier.id', $second->id);
    }

    public function test_only_the_holder_can_release_and_never_after_pickup(): void
    {
        $holder = User::factory()->courier()->create();
        $ready = $this->setStatus('ready', $holder);
        $pickedUp = $this->setStatus('picked_up', $holder);

        Sanctum::actingAs(User::factory()->courier()->create());
        $this->postJson("/api/v1/orders/{$ready->id}/release")->assertForbidden();

        Sanctum::actingAs($holder);
        $this->postJson("/api/v1/orders/{$pickedUp->id}/release")->assertForbidden();
        $this->assertSame($holder->id, $ready->fresh()->courier_id);
    }

    public function test_the_timeline_columns_follow_the_order(): void
    {
        $courier = User::factory()->courier()->create();
        $order = Order::factory()->create();
        $this->travelTo(now()->addMinutes(5));
        Sanctum::actingAs($order->restaurant->owner);
        foreach (['accepted', 'preparing', 'ready'] as $status) {
            $this->patchJson("/api/v1/orders/{$order->id}/status", ['status' => $status])->assertOk();
        }

        $order->refresh();
        $this->assertTrue($order->status_changed_at->isSameMinute(now()));
        $this->assertTrue($order->available_at->isSameMinute(now()));
        $this->assertNull($order->claimed_at);

        Sanctum::actingAs($courier);
        $this->postJson("/api/v1/orders/{$order->id}/claim")->assertOk();
        $this->assertNotNull($order->fresh()->claimed_at);
    }

    public function test_available_orders_are_listed_oldest_availability_first(): void
    {
        $newer = $this->setStatus('ready');
        $older = $this->setStatus('ready');
        Order::whereKey($older->id)->update(['available_at' => now()->subMinutes(10)]);
        Sanctum::actingAs(User::factory()->courier()->create());

        $ids = collect($this->getJson('/api/v1/courier/available-orders')->json('data'))->pluck('id')->all();

        $this->assertSame([$older->id, $newer->id], $ids);
    }

    public function test_the_actor_of_an_automatic_change_is_the_system(): void
    {
        $this->assertSame(OrderActor::System, OrderActor::forRole(null));
    }
}
