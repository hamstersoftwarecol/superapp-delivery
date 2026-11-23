<?php

namespace Tests\Feature\Console;

use App\Enums\AccountStatus;
use App\Enums\UserRole;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class CreateAdminCommandTest extends TestCase
{
    use RefreshDatabase;

    private const PASSWORD_PROMPT = 'Contraseña (mínimo 8 caracteres)';

    private const REPEAT_PROMPT = 'Repite la contraseña';

    public function test_it_creates_an_approved_admin_who_can_sign_in(): void
    {
        $this->artisan('admin:create', ['email' => 'jefe@example.test', '--name' => 'La Jefa'])
            ->expectsQuestion(self::PASSWORD_PROMPT, 'secret-password')
            ->expectsQuestion(self::REPEAT_PROMPT, 'secret-password')
            ->expectsOutputToContain('jefe@example.test')
            ->assertSuccessful();

        $admin = User::where('email', 'jefe@example.test')->firstOrFail();
        $this->assertSame(UserRole::Admin, $admin->role);
        $this->assertSame(AccountStatus::Approved, $admin->status);
        $this->assertSame('La Jefa', $admin->name);

        $this->postJson('/api/v1/auth/login', ['email' => 'jefe@example.test', 'password' => 'secret-password'])
            ->assertOk()
            ->assertJsonPath('user.role', 'admin');
    }

    public function test_the_name_defaults_to_the_local_part_of_the_email(): void
    {
        $this->artisan('admin:create', ['email' => 'soporte@example.test'])
            ->expectsQuestion(self::PASSWORD_PROMPT, 'secret-password')
            ->expectsQuestion(self::REPEAT_PROMPT, 'secret-password')
            ->assertSuccessful();

        $this->assertSame('soporte', User::where('email', 'soporte@example.test')->value('name'));
    }

    public function test_it_refuses_mismatching_passwords(): void
    {
        $this->artisan('admin:create', ['email' => 'jefe@example.test'])
            ->expectsQuestion(self::PASSWORD_PROMPT, 'secret-password')
            ->expectsQuestion(self::REPEAT_PROMPT, 'otra-cosa-distinta')
            ->assertFailed();

        $this->assertDatabaseMissing('users', ['email' => 'jefe@example.test']);
    }

    public function test_it_refuses_a_short_password(): void
    {
        $this->artisan('admin:create', ['email' => 'jefe@example.test'])
            ->expectsQuestion(self::PASSWORD_PROMPT, 'corta')
            ->assertFailed();

        $this->assertDatabaseMissing('users', ['email' => 'jefe@example.test']);
    }

    public function test_it_refuses_an_email_that_already_exists(): void
    {
        User::factory()->create(['email' => 'jefe@example.test']);

        $this->artisan('admin:create', ['email' => 'jefe@example.test'])->assertFailed();

        $this->assertSame(1, User::where('email', 'jefe@example.test')->count());
    }

    public function test_it_refuses_an_invalid_email(): void
    {
        $this->artisan('admin:create', ['email' => 'no-es-un-correo'])->assertFailed();

        $this->assertSame(0, User::count());
    }
}
