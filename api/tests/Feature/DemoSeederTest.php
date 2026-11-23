<?php

namespace Tests\Feature;

use App\Enums\OrderStatus;
use App\Models\Order;
use App\Models\Restaurant;
use App\Models\User;
use Database\Seeders\DemoSeeder;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class DemoSeederTest extends TestCase
{
    use RefreshDatabase;

    public function test_it_creates_one_account_per_role_and_every_order_stage(): void
    {
        $this->seed(DemoSeeder::class);

        $this->assertDatabaseHas('users', ['email' => DemoSeeder::CUSTOMER_EMAIL, 'role' => 'customer']);
        $this->assertDatabaseHas('users', ['email' => DemoSeeder::COURIER_EMAIL, 'role' => 'courier']);
        $this->assertDatabaseHas('users', ['email' => DemoSeeder::OWNER_EMAIL, 'role' => 'restaurant']);

        $this->assertSame(3, Restaurant::count());
        $this->assertSame(2, Restaurant::open()->count());

        foreach ([
            OrderStatus::Pending,
            OrderStatus::Preparing,
            OrderStatus::Ready,
            OrderStatus::PickedUp,
            OrderStatus::Delivered,
            OrderStatus::Cancelled,
            OrderStatus::Rejected,
            OrderStatus::Failed,
        ] as $status) {
            $this->assertSame(1, Order::where('status', $status)->count(), "Falta un pedido en estado {$status->value}");
        }
    }

    public function test_it_includes_an_admin_and_accounts_waiting_for_review(): void
    {
        $this->seed(DemoSeeder::class);

        $this->assertDatabaseHas('users', ['email' => DemoSeeder::ADMIN_EMAIL, 'role' => 'admin', 'status' => 'approved']);
        $this->assertDatabaseHas('users', ['email' => DemoSeeder::PENDING_COURIER_EMAIL, 'status' => 'pending']);
        $this->assertDatabaseHas('users', ['email' => DemoSeeder::PENDING_OWNER_EMAIL, 'status' => 'pending']);
    }

    public function test_orders_that_ended_badly_say_who_decided_and_why(): void
    {
        $this->seed(DemoSeeder::class);

        foreach ([OrderStatus::Cancelled, OrderStatus::Rejected, OrderStatus::Failed] as $status) {
            $order = Order::where('status', $status)->firstOrFail();

            $this->assertNotEmpty($order->status_reason, "{$status->value} sin motivo");
            $this->assertNotNull($order->status_actor);
        }
    }

    public function test_seeded_order_totals_add_up(): void
    {
        $this->seed(DemoSeeder::class);

        Order::with('items')->get()->each(function (Order $order) {
            $subtotal = $order->items->sum(fn ($item) => $item->unit_price_cents * $item->quantity);

            $this->assertSame($subtotal, $order->subtotal_cents);
            $this->assertSame($subtotal + $order->delivery_fee_cents, $order->total_cents);
        });
    }

    public function test_the_demo_accounts_can_sign_in(): void
    {
        $this->seed(DemoSeeder::class);

        foreach ([DemoSeeder::CUSTOMER_EMAIL, DemoSeeder::COURIER_EMAIL, DemoSeeder::OWNER_EMAIL] as $email) {
            $this->postJson('/api/v1/auth/login', ['email' => $email, 'password' => DemoSeeder::PASSWORD])
                ->assertOk()
                ->assertJsonStructure(['token']);
        }
    }

    public function test_a_courier_sees_the_ready_order_waiting_for_pickup(): void
    {
        $this->seed(DemoSeeder::class);

        $token = $this->postJson('/api/v1/auth/login', [
            'email' => DemoSeeder::COURIER_EMAIL,
            'password' => DemoSeeder::PASSWORD,
        ])->json('token');

        $this->withToken($token)
            ->getJson('/api/v1/courier/available-orders')
            ->assertOk()
            ->assertJsonCount(1, 'data');
    }

    public function test_running_it_twice_does_not_duplicate_anything(): void
    {
        $this->seed(DemoSeeder::class);
        $this->seed(DemoSeeder::class);

        $this->assertSame(7, User::count());
        $this->assertSame(3, Restaurant::count());
        $this->assertSame(8, Order::count());
    }

    public function test_it_does_nothing_in_production(): void
    {
        $this->app['env'] = 'production';

        $this->seed(DemoSeeder::class);

        $this->assertSame(0, User::count());
    }
}
