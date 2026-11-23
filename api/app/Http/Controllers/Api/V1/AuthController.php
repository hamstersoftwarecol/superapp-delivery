<?php

namespace App\Http\Controllers\Api\V1;

use App\Enums\AccountStatus;
use App\Enums\UserRole;
use App\Http\Controllers\Controller;
use App\Http\Requests\Api\V1\ForgotPasswordRequest;
use App\Http\Requests\Api\V1\LoginRequest;
use App\Http\Requests\Api\V1\RegisterRequest;
use App\Http\Requests\Api\V1\ResetPasswordRequest;
use App\Http\Resources\AccountResource;
use App\Models\User;
use Illuminate\Auth\Events\PasswordReset;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Http\Response;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\Password;
use Illuminate\Support\Str;
use Illuminate\Validation\ValidationException;

class AuthController extends Controller
{
    public function register(RegisterRequest $request): JsonResponse
    {
        $user = new User($request->safe()->except('role'));

        $role = UserRole::from($request->validated('role'));

        // Restaurants and couriers must be reviewed by an admin before working.
        $user->forceFill([
            'role' => $role,
            'status' => $role->requiresApproval() ? AccountStatus::Pending : AccountStatus::Approved,
        ])->save();

        return $this->tokenResponse($user, 'mobile', 201);
    }

    public function login(LoginRequest $request): JsonResponse
    {
        $user = User::where('email', $request->validated('email'))->first();

        if (! $user || ! Hash::check($request->validated('password'), $user->password)) {
            throw ValidationException::withMessages(['email' => 'Las credenciales no son correctas.']);
        }

        if ($user->status === AccountStatus::Suspended) {
            return response()->json([
                'message' => 'Tu cuenta fue suspendida. Contacta a soporte.',
                'code' => 'account_suspended',
            ], 403);
        }

        return $this->tokenResponse($user, $request->validated('device_name') ?? 'mobile');
    }

    public function logout(Request $request): Response
    {
        $request->user()->currentAccessToken()->delete();

        return response()->noContent();
    }

    public function me(Request $request): AccountResource
    {
        return new AccountResource($request->user());
    }

    /**
     * Always answers the same way so it cannot be used to discover which
     * emails have an account.
     */
    public function forgotPassword(ForgotPasswordRequest $request): JsonResponse
    {
        Password::sendResetLink($request->safe()->only('email'));

        return response()->json([
            'message' => 'Si el correo está registrado, te enviamos las instrucciones para recuperar tu contraseña.',
        ]);
    }

    public function resetPassword(ResetPasswordRequest $request): JsonResponse
    {
        $status = Password::reset(
            $request->safe()->only('email', 'token', 'password'),
            function (User $user, string $password) {
                $user->forceFill([
                    'password' => $password,
                    'remember_token' => Str::random(60),
                ])->save();

                // Whoever knew the old password (or stole a token) is signed out everywhere.
                $user->tokens()->delete();

                event(new PasswordReset($user));
            },
        );

        if ($status !== Password::PASSWORD_RESET) {
            throw ValidationException::withMessages([
                'email' => 'El enlace no es válido o ya venció. Pide uno nuevo.',
            ]);
        }

        return response()->json(['message' => 'Tu contraseña fue actualizada. Ya puedes iniciar sesión.']);
    }

    private function tokenResponse(User $user, string $deviceName, int $status = 200): JsonResponse
    {
        return response()->json([
            'token' => $user->createToken($deviceName)->plainTextToken,
            'user' => new AccountResource($user),
        ], $status);
    }
}
