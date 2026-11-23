<?php

namespace Tests\Feature\Api\V1;

use App\Models\User;
use App\Notifications\ResetPasswordNotification;
use Illuminate\Auth\Events\PasswordReset;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Event;
use Illuminate\Support\Facades\Notification;
use Illuminate\Support\Facades\Password;
use Tests\TestCase;

class PasswordResetTest extends TestCase
{
    use RefreshDatabase;

    public function test_a_registered_user_receives_the_reset_email(): void
    {
        Notification::fake();
        $user = User::factory()->create();

        $this->postJson('/api/v1/auth/forgot-password', ['email' => $user->email])->assertOk();

        Notification::assertSentTo($user, ResetPasswordNotification::class);
    }

    public function test_an_unknown_email_gets_the_same_answer_and_nothing_is_sent(): void
    {
        Notification::fake();
        $known = User::factory()->create();

        $forKnown = $this->postJson('/api/v1/auth/forgot-password', ['email' => $known->email]);
        $forUnknown = $this->postJson('/api/v1/auth/forgot-password', ['email' => 'nadie@example.test']);

        $forUnknown->assertOk();
        $this->assertSame($forKnown->json(), $forUnknown->json());
        Notification::assertSentTimes(ResetPasswordNotification::class, 1);
    }

    public function test_the_email_must_be_valid(): void
    {
        $this->postJson('/api/v1/auth/forgot-password', ['email' => 'no-es-un-correo'])
            ->assertUnprocessable()
            ->assertJsonValidationErrors('email');
    }

    public function test_the_email_links_to_the_web_panel_with_the_token(): void
    {
        config(['app.frontend_url' => 'https://panel.example.test/']);
        $user = User::factory()->create(['email' => 'ana+prueba@example.test']);

        $mail = (new ResetPasswordNotification('abc123'))->toMail($user);

        $this->assertSame('Recupera tu contraseña', $mail->subject);
        $this->assertStringStartsWith('https://panel.example.test/reset-password?', $mail->actionUrl);
        parse_str(parse_url($mail->actionUrl, PHP_URL_QUERY), $query);
        $this->assertSame('abc123', $query['token']);
        $this->assertSame('ana+prueba@example.test', $query['email']);
    }

    public function test_a_valid_token_sets_the_new_password_and_signs_the_user_out_everywhere(): void
    {
        Event::fake([PasswordReset::class]);
        $user = User::factory()->create(['password' => 'old-password']);
        $user->createToken('phone');
        $token = Password::createToken($user);

        $this->postJson('/api/v1/auth/reset-password', [
            'email' => $user->email,
            'token' => $token,
            'password' => 'brand-new-password',
        ])->assertOk();

        $this->assertSame(0, $user->tokens()->count());
        Event::assertDispatched(PasswordReset::class);

        $this->postJson('/api/v1/auth/login', ['email' => $user->email, 'password' => 'old-password'])->assertUnprocessable();
        $this->postJson('/api/v1/auth/login', ['email' => $user->email, 'password' => 'brand-new-password'])->assertOk();
    }

    public function test_a_token_works_only_once(): void
    {
        $user = User::factory()->create();
        $token = Password::createToken($user);
        $payload = ['email' => $user->email, 'token' => $token, 'password' => 'brand-new-password'];

        $this->postJson('/api/v1/auth/reset-password', $payload)->assertOk();
        $this->postJson('/api/v1/auth/reset-password', [...$payload, 'password' => 'another-password'])
            ->assertUnprocessable()
            ->assertJsonValidationErrors('email');
    }

    public function test_a_wrong_token_changes_nothing(): void
    {
        $user = User::factory()->create(['password' => 'old-password']);

        $this->postJson('/api/v1/auth/reset-password', [
            'email' => $user->email,
            'token' => 'not-the-token',
            'password' => 'brand-new-password',
        ])->assertUnprocessable()->assertJsonValidationErrors('email');

        $this->postJson('/api/v1/auth/login', ['email' => $user->email, 'password' => 'old-password'])->assertOk();
    }

    public function test_a_token_cannot_be_used_for_another_email(): void
    {
        $owner = User::factory()->create();
        $other = User::factory()->create(['password' => 'old-password']);

        $this->postJson('/api/v1/auth/reset-password', [
            'email' => $other->email,
            'token' => Password::createToken($owner),
            'password' => 'brand-new-password',
        ])->assertUnprocessable();

        $this->postJson('/api/v1/auth/login', ['email' => $other->email, 'password' => 'old-password'])->assertOk();
    }

    public function test_an_expired_token_is_rejected(): void
    {
        $user = User::factory()->create();
        $token = Password::createToken($user);

        $this->travel(61)->minutes();

        $this->postJson('/api/v1/auth/reset-password', [
            'email' => $user->email,
            'token' => $token,
            'password' => 'brand-new-password',
        ])->assertUnprocessable()->assertJsonValidationErrors('email');
    }

    public function test_the_new_password_must_be_strong_enough(): void
    {
        $user = User::factory()->create();

        $this->postJson('/api/v1/auth/reset-password', [
            'email' => $user->email,
            'token' => Password::createToken($user),
            'password' => 'corta',
        ])->assertUnprocessable()->assertJsonValidationErrors('password');
    }

    public function test_requesting_resets_is_rate_limited(): void
    {
        foreach (range(1, 5) as $_) {
            $this->postJson('/api/v1/auth/forgot-password', ['email' => 'nadie@example.test'])->assertOk();
        }

        $this->postJson('/api/v1/auth/forgot-password', ['email' => 'nadie@example.test'])->assertTooManyRequests();
    }
}
