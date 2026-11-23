<?php

namespace Tests\Feature\Api\V1;

use App\Enums\OrderStatus;
use App\Models\Order;
use App\Models\Restaurant;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class PaginationTest extends TestCase
{
    use RefreshDatabase;

    /**
     * Follows `meta.next_cursor` until the end and returns every page's ids.
     *
     * @return list<list<int>>
     */
    private function pages(string $url): array
    {
        $pages = [];
        $cursor = null;

        do {
            $response = $this->getJson($url.($cursor ? (str_contains($url, '?') ? '&' : '?')."cursor={$cursor}" : ''))->assertOk();
            $pages[] = collect($response->json('data'))->pluck('id')->all();
            $cursor = $response->json('meta.next_cursor');
        } while ($cursor !== null && count($pages) < 10);

        return $pages;
    }

    public function test_restaurants_come_in_pages_of_twenty_without_repeats_or_gaps(): void
    {
        foreach (range(1, 25) as $n) {
            Restaurant::factory()->create(['name' => sprintf('Restaurante %02d', $n)]);
        }

        $pages = $this->pages('/api/v1/restaurants');

        $this->assertCount(2, $pages);
        $this->assertCount(20, $pages[0]);
        $this->assertCount(5, $pages[1]);
        $this->assertCount(25, array_unique([...$pages[0], ...$pages[1]]));
    }

    public function test_the_last_page_has_no_next_cursor(): void
    {
        Restaurant::factory()->count(3)->create();

        $this->getJson('/api/v1/restaurants')->assertOk()->assertJsonPath('meta.next_cursor', null);
    }

    public function test_restaurants_with_the_same_name_are_not_lost_between_pages(): void
    {
        Restaurant::factory()->count(25)->create(['name' => 'Tacos']);

        $ids = collect($this->pages('/api/v1/restaurants'))->flatten();

        $this->assertCount(25, $ids->unique());
    }

    public function test_orders_are_paged_newest_first(): void
    {
        $customer = User::factory()->create();
        $orders = collect(range(1, 25))->map(fn ($n) => Order::factory()->for($customer, 'customer')->create(['created_at' => now()->subMinutes(100 - $n)]));
        Sanctum::actingAs($customer);

        $pages = $this->pages('/api/v1/orders');

        $this->assertCount(20, $pages[0]);
        $this->assertCount(5, $pages[1]);
        $this->assertSame($orders->pluck('id')->reverse()->values()->all(), [...$pages[0], ...$pages[1]]);
    }

    public function test_a_new_order_arriving_between_pages_does_not_duplicate_or_skip_anything(): void
    {
        $customer = User::factory()->create();
        collect(range(1, 25))->each(fn ($n) => Order::factory()->for($customer, 'customer')->create(['created_at' => now()->subMinutes(100 - $n)]));
        Sanctum::actingAs($customer);

        $first = $this->getJson('/api/v1/orders')->assertOk();
        $firstIds = collect($first->json('data'))->pluck('id');

        Order::factory()->for($customer, 'customer')->create(['created_at' => now()]);

        $second = $this->getJson('/api/v1/orders?cursor='.$first->json('meta.next_cursor'))->assertOk();
        $secondIds = collect($second->json('data'))->pluck('id');

        $this->assertCount(5, $secondIds);
        $this->assertEmpty($firstIds->intersect($secondIds)->all());
    }

    public function test_the_active_scope_returns_every_order_in_progress_without_pages(): void
    {
        $restaurant = Restaurant::factory()->create();
        Order::factory()->count(25)->for($restaurant)->create(['status' => OrderStatus::Preparing]);
        Order::factory()->count(3)->for($restaurant)->create(['status' => OrderStatus::Delivered]);
        Order::factory()->count(2)->for($restaurant)->create(['status' => OrderStatus::Cancelled]);
        Sanctum::actingAs($restaurant->owner);

        $response = $this->getJson('/api/v1/orders?scope=active')->assertOk();

        $this->assertCount(25, $response->json('data'), 'all 25 active orders, not just the first page');
        $this->assertArrayNotHasKey('meta', $response->json());
        $this->assertSame(['preparing'], collect($response->json('data'))->pluck('status')->unique()->values()->all());
    }

    public function test_the_history_scope_pages_only_finished_orders(): void
    {
        $restaurant = Restaurant::factory()->create();
        Order::factory()->count(22)->for($restaurant)->create(['status' => OrderStatus::Delivered]);
        Order::factory()->count(4)->for($restaurant)->create(['status' => OrderStatus::Pending]);
        Sanctum::actingAs($restaurant->owner);

        $pages = $this->pages('/api/v1/orders?scope=history');

        $this->assertSame([20, 2], array_map('count', $pages));
    }

    public function test_an_unknown_scope_is_rejected(): void
    {
        Sanctum::actingAs(User::factory()->create());

        $this->getJson('/api/v1/orders?scope=todo')->assertUnprocessable()->assertJsonValidationErrors('scope');
    }

    public function test_available_orders_are_paged_oldest_first(): void
    {
        $orders = collect(range(1, 25))->map(function ($n) {
            $order = Order::factory()->create(['status' => OrderStatus::Ready]);
            Order::whereKey($order->id)->update(['available_at' => now()->subMinutes(100 - $n)]);

            return $order;
        });
        Sanctum::actingAs(User::factory()->courier()->create());

        $pages = $this->pages('/api/v1/courier/available-orders');

        $this->assertSame([20, 5], array_map('count', $pages));
        $this->assertSame($orders->pluck('id')->all(), [...$pages[0], ...$pages[1]]);
    }

    public function test_the_admin_account_list_keeps_numbered_pages(): void
    {
        User::factory()->count(55)->create();
        Sanctum::actingAs(User::factory()->admin()->create());

        $this->getJson('/api/v1/admin/accounts')
            ->assertOk()
            ->assertJsonCount(50, 'data')
            ->assertJsonPath('meta.current_page', 1)
            ->assertJsonPath('meta.last_page', 2);
        $this->getJson('/api/v1/admin/accounts?page=2')->assertOk()->assertJsonCount(5, 'data');
    }
}
