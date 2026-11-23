<?php

namespace Tests\Feature\Api\V1;

use App\Models\MenuItem;
use App\Models\Restaurant;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class RestaurantMenuTest extends TestCase
{
    use RefreshDatabase;

    public function test_guests_only_see_open_restaurants(): void
    {
        $open = Restaurant::factory()->create(['is_open' => true]);
        Restaurant::factory()->create(['is_open' => false]);

        $this->getJson('/api/v1/restaurants')
            ->assertOk()
            ->assertJsonCount(1, 'data')
            ->assertJsonPath('data.0.id', $open->id);
    }

    public function test_restaurant_detail_lists_only_available_menu_items(): void
    {
        $restaurant = Restaurant::factory()->create();
        MenuItem::factory()->for($restaurant)->create(['is_available' => true]);
        MenuItem::factory()->for($restaurant)->create(['is_available' => false]);

        $this->getJson("/api/v1/restaurants/{$restaurant->id}")
            ->assertOk()
            ->assertJsonCount(1, 'data.menu_items');
    }

    public function test_a_restaurant_owner_can_create_a_restaurant_and_menu_item(): void
    {
        $owner = User::factory()->restaurantOwner()->create();
        Sanctum::actingAs($owner);

        $restaurantId = $this->postJson('/api/v1/restaurants', [
            'name' => 'Tacos Don Pepe',
            'address' => 'Calle 1 # 2-3',
            'delivery_fee_cents' => 300,
            'is_open' => true,
        ])->assertCreated()->json('data.id');

        $this->postJson("/api/v1/restaurants/{$restaurantId}/menu-items", [
            'name' => 'Taco al pastor',
            'price_cents' => 450,
        ])->assertCreated()->assertJsonPath('data.price_cents', 450);

        $this->assertDatabaseHas('restaurants', ['id' => $restaurantId, 'owner_id' => $owner->id]);
    }

    public function test_a_customer_cannot_create_a_restaurant(): void
    {
        Sanctum::actingAs(User::factory()->create());

        $this->postJson('/api/v1/restaurants', [
            'name' => 'Nope',
            'address' => 'Calle 1',
        ])->assertForbidden();
    }

    public function test_an_owner_cannot_edit_another_owners_restaurant_or_menu(): void
    {
        $restaurant = Restaurant::factory()->create();
        $menuItem = MenuItem::factory()->for($restaurant)->create();
        Sanctum::actingAs(User::factory()->restaurantOwner()->create());

        $this->patchJson("/api/v1/restaurants/{$restaurant->id}", ['name' => 'Hacked'])->assertForbidden();
        $this->patchJson("/api/v1/menu-items/{$menuItem->id}", ['price_cents' => 1])->assertForbidden();
        $this->deleteJson("/api/v1/menu-items/{$menuItem->id}")->assertForbidden();
    }
}
