<?php

namespace Tests\Feature\Api\V1;

use App\Enums\UserRole;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class AuthTest extends TestCase
{
    use RefreshDatabase;

    public function test_a_user_can_register_with_a_role_and_receives_a_token(): void
    {
        $response = $this->postJson('/api/v1/auth/register', [
            'name' => 'Ana Cliente',
            'email' => 'ana@example.com',
            'password' => 'secret-password',
            'role' => 'courier',
        ]);

        $response->assertCreated()
            ->assertJsonPath('user.role', 'courier')
            ->assertJsonStructure(['token', 'user' => ['id', 'name', 'email', 'role']]);

        $this->assertDatabaseHas('users', ['email' => 'ana@example.com', 'role' => UserRole::Courier->value]);
    }

    public function test_customers_are_approved_at_once_but_restaurants_and_couriers_start_pending(): void
    {
        foreach (['customer' => 'approved', 'restaurant' => 'pending', 'courier' => 'pending'] as $role => $status) {
            $this->postJson('/api/v1/auth/register', [
                'name' => "Alguien {$role}",
                'email' => "{$role}@example.test",
                'password' => 'secret-password',
                'role' => $role,
            ])->assertCreated()->assertJsonPath('user.status', $status);
        }
    }

    public function test_nobody_can_register_as_an_admin(): void
    {
        $this->postJson('/api/v1/auth/register', [
            'name' => 'Intruso',
            'email' => 'intruso@example.test',
            'password' => 'secret-password',
            'role' => 'admin',
        ])->assertUnprocessable()->assertJsonValidationErrors('role');

        $this->assertDatabaseMissing('users', ['email' => 'intruso@example.test']);
    }

    public function test_registration_rejects_an_unknown_role(): void
    {
        $this->postJson('/api/v1/auth/register', [
            'name' => 'Ana',
            'email' => 'ana@example.com',
            'password' => 'secret-password',
            'role' => 'admin',
        ])->assertUnprocessable()->assertJsonValidationErrors('role');
    }

    public function test_a_user_can_log_in_and_fetch_their_profile(): void
    {
        $user = User::factory()->create(['password' => 'secret-password']);

        $token = $this->postJson('/api/v1/auth/login', [
            'email' => $user->email,
            'password' => 'secret-password',
        ])->assertOk()->json('token');

        $this->withToken($token)
            ->getJson('/api/v1/me')
            ->assertOk()
            ->assertJsonPath('data.id', $user->id);
    }

    public function test_login_fails_with_wrong_credentials(): void
    {
        $user = User::factory()->create();

        $this->postJson('/api/v1/auth/login', [
            'email' => $user->email,
            'password' => 'wrong-password',
        ])->assertUnprocessable()->assertJsonValidationErrors('email');
    }

    public function test_protected_routes_require_a_token(): void
    {
        $this->getJson('/api/v1/me')->assertUnauthorized();
    }

    public function test_unauthenticated_requests_without_a_json_accept_header_still_get_a_401(): void
    {
        $this->get('/api/v1/me')->assertUnauthorized();
    }
}
