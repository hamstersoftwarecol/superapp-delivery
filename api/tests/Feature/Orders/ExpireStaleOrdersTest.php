<?php

namespace Tests\Feature\Orders;

use App\Actions\ExpireStaleOrders;
use App\Enums\OrderActor;
use App\Enums\OrderStatus;
use App\Models\Order;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class ExpireStaleOrdersTest extends TestCase
{
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();

        config([
            'delivery.pending_timeout_minutes' => 10,
            'delivery.unclaimed_timeout_minutes' => 30,
            'delivery.claim_timeout_minutes' => 20,
        ]);
    }

    /**
     * @param  array<string, mixed>  $attributes
     */
    private function order(OrderStatus $status, int $minutesAgo, array $attributes = []): Order
    {
        $order = Order::factory()->create(['status' => $status, ...$attributes]);

        Order::whereKey($order->id)->update([
            'status_changed_at' => now()->subMinutes($minutesAgo),
            'available_at' => $status === OrderStatus::Ready ? now()->subMinutes($minutesAgo) : null,
            'claimed_at' => $attributes['courier_id'] ?? null ? now()->subMinutes($minutesAgo) : null,
        ]);

        return $order->fresh();
    }

    public function test_a_pending_order_the_restaurant_ignored_is_cancelled(): void
    {
        $stale = $this->order(OrderStatus::Pending, 11);
        $recent = $this->order(OrderStatus::Pending, 5);

        $result = app(ExpireStaleOrders::class)->handle();

        $this->assertSame(1, $result['cancelled_pending']);
        $stale->refresh();
        $this->assertSame(OrderStatus::Cancelled, $stale->status);
        $this->assertSame(OrderActor::System, $stale->status_actor);
        $this->assertSame('El restaurante no respondió a tiempo.', $stale->status_reason);
        $this->assertSame(OrderStatus::Pending, $recent->fresh()->status);
    }

    public function test_orders_the_restaurant_is_working_on_are_never_expired(): void
    {
        $accepted = $this->order(OrderStatus::Accepted, 600);
        $preparing = $this->order(OrderStatus::Preparing, 600);

        app(ExpireStaleOrders::class)->handle();

        $this->assertSame(OrderStatus::Accepted, $accepted->fresh()->status);
        $this->assertSame(OrderStatus::Preparing, $preparing->fresh()->status);
    }

    public function test_a_ready_order_without_a_courier_is_cancelled_after_the_limit(): void
    {
        $stale = $this->order(OrderStatus::Ready, 31);
        $recent = $this->order(OrderStatus::Ready, 29);

        $result = app(ExpireStaleOrders::class)->handle();

        $this->assertSame(1, $result['cancelled_unclaimed']);
        $this->assertSame(OrderStatus::Cancelled, $stale->fresh()->status);
        $this->assertSame('No hubo un repartidor disponible a tiempo.', $stale->fresh()->status_reason);
        $this->assertSame(OrderStatus::Ready, $recent->fresh()->status);
    }

    public function test_an_order_a_courier_took_but_never_picked_up_goes_back_to_the_pool(): void
    {
        $courier = User::factory()->courier()->create();
        $abandoned = $this->order(OrderStatus::Ready, 25, ['courier_id' => $courier->id]);
        $recent = $this->order(OrderStatus::Ready, 5, ['courier_id' => $courier->id]);

        $result = app(ExpireStaleOrders::class)->handle();

        $this->assertSame(1, $result['released']);
        $abandoned->refresh();
        $this->assertNull($abandoned->courier_id);
        $this->assertNull($abandoned->claimed_at);
        $this->assertSame(OrderStatus::Ready, $abandoned->status);
        $this->assertSame($courier->id, $recent->fresh()->courier_id);
    }

    public function test_a_released_order_gets_a_fresh_window_instead_of_being_cancelled_at_once(): void
    {
        $courier = User::factory()->courier()->create();
        // Ready for 40 minutes, but a courier held it until now.
        $order = $this->order(OrderStatus::Ready, 40, ['courier_id' => $courier->id]);

        $result = app(ExpireStaleOrders::class)->handle();

        $this->assertSame(1, $result['released']);
        $this->assertSame(0, $result['cancelled_unclaimed']);
        $this->assertSame(OrderStatus::Ready, $order->fresh()->status);
    }

    public function test_orders_already_on_their_way_or_finished_are_left_alone(): void
    {
        $courier = User::factory()->courier()->create();
        $onTheWay = $this->order(OrderStatus::PickedUp, 600, ['courier_id' => $courier->id]);
        $delivered = $this->order(OrderStatus::Delivered, 600, ['courier_id' => $courier->id]);

        app(ExpireStaleOrders::class)->handle();

        $this->assertSame(OrderStatus::PickedUp, $onTheWay->fresh()->status);
        $this->assertSame(OrderStatus::Delivered, $delivered->fresh()->status);
    }

    public function test_the_limits_come_from_the_configuration(): void
    {
        config(['delivery.pending_timeout_minutes' => 2]);
        $order = $this->order(OrderStatus::Pending, 3);

        app(ExpireStaleOrders::class)->handle();

        $this->assertSame(OrderStatus::Cancelled, $order->fresh()->status);
    }

    public function test_running_it_twice_changes_nothing_the_second_time(): void
    {
        $this->order(OrderStatus::Pending, 30);

        $first = app(ExpireStaleOrders::class)->handle();
        $second = app(ExpireStaleOrders::class)->handle();

        $this->assertSame(1, $first['cancelled_pending']);
        $this->assertSame(['cancelled_pending' => 0, 'cancelled_unclaimed' => 0, 'released' => 0], $second);
    }

    public function test_the_command_reports_what_it_did(): void
    {
        $this->order(OrderStatus::Pending, 30);

        $this->artisan('orders:expire-stale')
            ->expectsOutputToContain('Cancelados sin respuesta del restaurante: 1')
            ->assertSuccessful();
    }

    public function test_the_scheduler_runs_it_every_minute(): void
    {
        $this->artisan('schedule:list')
            ->expectsOutputToContain('orders:expire-stale')
            ->assertSuccessful();
    }
}
