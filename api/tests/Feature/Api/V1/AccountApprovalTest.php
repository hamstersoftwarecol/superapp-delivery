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

class AccountApprovalTest extends TestCase
{
    use RefreshDatabase;

    public function test_a_pending_account_can_still_see_its_profile_and_sign_out(): void
    {
        $owner = User::factory()->restaurantOwner()->pending()->create();
        $token = $owner->createToken('test')->plainTextToken;

        $this->withToken($token)->getJson('/api/v1/me')
            ->assertOk()
            ->assertJsonPath('data.status', 'pending');

        $this->withToken($token)->postJson('/api/v1/auth/logout')->assertNoContent();
    }

    public function test_a_pending_restaurant_can_prepare_its_profile_and_menu_but_not_handle_orders(): void
    {
        Sanctum::actingAs(User::factory()->restaurantOwner()->pending()->create());

        $restaurantId = $this->postJson('/api/v1/restaurants', ['name' => 'Mi local', 'address' => 'Calle 1', 'is_open' => true])
            ->assertCreated()
            ->json('data.id');
        $this->postJson("/api/v1/restaurants/{$restaurantId}/menu-items", ['name' => 'Taco', 'price_cents' => 450000])->assertCreated();
        $this->getJson('/api/v1/owner/restaurants')->assertOk()->assertJsonCount(1, 'data');

        $this->getJson('/api/v1/orders')->assertForbidden()->assertJsonPath('code', 'account_pending');

        // Customers still cannot see it until an admin approves the account.
        $this->app['auth']->forgetGuards();
        $this->getJson('/api/v1/restaurants')->assertJsonCount(0, 'data');
    }

    public function test_a_suspended_restaurant_cannot_even_edit_its_profile(): void
    {
        $owner = User::factory()->restaurantOwner()->suspended()->create();
        Sanctum::actingAs($owner);

        $this->postJson('/api/v1/restaurants', ['name' => 'Mi local', 'address' => 'Calle 1'])
            ->assertForbidden()
            ->assertJsonPath('code', 'account_suspended');
    }

    public function test_a_pending_courier_cannot_see_or_claim_orders(): void
    {
        $order = Order::factory()->create(['status' => OrderStatus::Ready]);
        Sanctum::actingAs(User::factory()->courier()->pending()->create());

        $this->getJson('/api/v1/courier/available-orders')->assertForbidden()->assertJsonPath('code', 'account_pending');
        $this->postJson("/api/v1/orders/{$order->id}/claim")->assertForbidden();
        $this->assertNull($order->fresh()->courier_id);
    }

    public function test_a_suspended_account_is_blocked_everywhere_except_its_profile(): void
    {
        $courier = User::factory()->courier()->suspended()->create();
        Sanctum::actingAs($courier);

        $this->getJson('/api/v1/courier/available-orders')
            ->assertForbidden()
            ->assertJsonPath('code', 'account_suspended');
        $this->getJson('/api/v1/me')->assertOk();
    }

    public function test_a_suspended_account_cannot_sign_in(): void
    {
        $user = User::factory()->suspended()->create(['password' => 'secret-password']);

        $this->postJson('/api/v1/auth/login', ['email' => $user->email, 'password' => 'secret-password'])
            ->assertForbidden()
            ->assertJsonPath('code', 'account_suspended')
            ->assertJsonMissingPath('token');
    }

    public function test_a_pending_account_can_sign_in_to_see_its_status(): void
    {
        $user = User::factory()->courier()->pending()->create(['password' => 'secret-password']);

        $this->postJson('/api/v1/auth/login', ['email' => $user->email, 'password' => 'secret-password'])
            ->assertOk()
            ->assertJsonPath('user.status', 'pending');
    }

    public function test_customers_only_see_restaurants_of_approved_owners(): void
    {
        $approved = Restaurant::factory()->create();
        Restaurant::factory()->for(User::factory()->restaurantOwner()->pending(), 'owner')->create();
        Restaurant::factory()->for(User::factory()->restaurantOwner()->suspended(), 'owner')->create();

        $this->getJson('/api/v1/restaurants')
            ->assertOk()
            ->assertJsonCount(1, 'data')
            ->assertJsonPath('data.0.id', $approved->id);
    }

    public function test_the_detail_of_an_unapproved_restaurant_is_not_found(): void
    {
        $hidden = Restaurant::factory()->for(User::factory()->restaurantOwner()->pending(), 'owner')->create();

        $this->getJson("/api/v1/restaurants/{$hidden->id}")->assertNotFound();
    }

    public function test_an_order_cannot_be_placed_at_a_restaurant_whose_owner_is_not_approved(): void
    {
        $restaurant = Restaurant::factory()->for(User::factory()->restaurantOwner()->suspended(), 'owner')->create();
        $item = MenuItem::factory()->for($restaurant)->create();
        Sanctum::actingAs(User::factory()->create());

        $this->postJson('/api/v1/orders', [
            'restaurant_id' => $restaurant->id,
            'delivery_address' => 'Calle 1',
            'items' => [['menu_item_id' => $item->id, 'quantity' => 1]],
        ])->assertUnprocessable()->assertJsonValidationErrors('restaurant_id');

        $this->assertDatabaseCount('orders', 0);
    }
}
