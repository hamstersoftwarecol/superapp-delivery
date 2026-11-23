<?php

namespace Tests\Feature\Api\V1;

use App\Enums\AccountStatus;
use App\Models\Restaurant;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class AdminAccountsTest extends TestCase
{
    use RefreshDatabase;

    public function test_an_admin_lists_accounts_filtered_by_status_and_role(): void
    {
        $pendingCourier = User::factory()->courier()->pending()->create();
        User::factory()->courier()->create();
        User::factory()->restaurantOwner()->pending()->create();
        User::factory()->create();
        Sanctum::actingAs(User::factory()->admin()->create());

        $this->getJson('/api/v1/admin/accounts?status=pending&role=courier')
            ->assertOk()
            ->assertJsonCount(1, 'data')
            ->assertJsonPath('data.0.id', $pendingCourier->id)
            ->assertJsonPath('data.0.status', 'pending');
    }

    public function test_the_list_never_includes_admins(): void
    {
        $admin = User::factory()->admin()->create();
        User::factory()->create();
        Sanctum::actingAs($admin);

        $roles = collect($this->getJson('/api/v1/admin/accounts')->assertOk()->json('data'))->pluck('role');

        $this->assertNotContains('admin', $roles);
    }

    public function test_the_list_shows_the_restaurants_of_each_owner(): void
    {
        $owner = User::factory()->restaurantOwner()->pending()->create();
        Restaurant::factory()->for($owner, 'owner')->create(['name' => 'Tacos Pendientes']);
        Sanctum::actingAs(User::factory()->admin()->create());

        $this->getJson('/api/v1/admin/accounts?status=pending')
            ->assertOk()
            ->assertJsonPath('data.0.restaurants.0.name', 'Tacos Pendientes');
    }

    public function test_only_admins_can_use_the_admin_endpoints(): void
    {
        $target = User::factory()->courier()->pending()->create();

        foreach ([User::factory()->create(), User::factory()->restaurantOwner()->create(), User::factory()->courier()->create()] as $user) {
            Sanctum::actingAs($user);

            $this->getJson('/api/v1/admin/accounts')->assertForbidden();
            $this->patchJson("/api/v1/admin/accounts/{$target->id}/status", ['status' => 'approved'])->assertForbidden();
        }

        $this->assertSame(AccountStatus::Pending, $target->fresh()->status);
    }

    public function test_an_admin_approves_a_pending_account_and_it_can_work(): void
    {
        $courier = User::factory()->courier()->pending()->create();
        Sanctum::actingAs(User::factory()->admin()->create());

        $this->patchJson("/api/v1/admin/accounts/{$courier->id}/status", ['status' => 'approved'])
            ->assertOk()
            ->assertJsonPath('data.status', 'approved');

        Sanctum::actingAs($courier->fresh());
        $this->getJson('/api/v1/courier/available-orders')->assertOk();
    }

    public function test_suspending_records_the_reason_and_signs_the_user_out_everywhere(): void
    {
        $courier = User::factory()->courier()->create();
        $courier->createToken('phone');
        $courier->createToken('tablet');
        Sanctum::actingAs(User::factory()->admin()->create());

        $this->patchJson("/api/v1/admin/accounts/{$courier->id}/status", [
            'status' => 'suspended',
            'note' => 'Documentos incompletos',
        ])->assertOk()->assertJsonPath('data.status_note', 'Documentos incompletos');

        $this->assertSame(0, $courier->tokens()->count());
        $this->assertSame(AccountStatus::Suspended, $courier->fresh()->status);
    }

    public function test_approving_clears_a_previous_refusal_note(): void
    {
        $courier = User::factory()->courier()->suspended()->create(['status_note' => 'Faltaban documentos']);
        Sanctum::actingAs(User::factory()->admin()->create());

        $this->patchJson("/api/v1/admin/accounts/{$courier->id}/status", ['status' => 'approved'])->assertOk();

        $this->assertNull($courier->fresh()->status_note);
    }

    public function test_admins_cannot_change_their_own_or_another_admins_status(): void
    {
        $admin = User::factory()->admin()->create();
        $other = User::factory()->admin()->create();
        Sanctum::actingAs($admin);

        $this->patchJson("/api/v1/admin/accounts/{$admin->id}/status", ['status' => 'suspended'])->assertForbidden();
        $this->patchJson("/api/v1/admin/accounts/{$other->id}/status", ['status' => 'suspended'])->assertForbidden();

        $this->assertTrue($admin->fresh()->isApproved());
        $this->assertTrue($other->fresh()->isApproved());
    }

    public function test_the_status_must_be_approved_or_suspended(): void
    {
        $courier = User::factory()->courier()->create();
        Sanctum::actingAs(User::factory()->admin()->create());

        foreach (['pending', 'banana'] as $status) {
            $this->patchJson("/api/v1/admin/accounts/{$courier->id}/status", ['status' => $status])
                ->assertUnprocessable()
                ->assertJsonValidationErrors('status');
        }
    }
}
