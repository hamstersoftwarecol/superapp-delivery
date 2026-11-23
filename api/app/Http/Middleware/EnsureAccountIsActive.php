<?php

namespace App\Http\Middleware;

use App\Enums\AccountStatus;
use Closure;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\Response;

/**
 * Lets only approved accounts through. Pending and suspended ones can still
 * reach /me and /auth/logout (those routes are outside this middleware) so
 * the apps can tell them why they are blocked.
 *
 * With the `pending-ok` parameter (`active:pending-ok`) pending accounts also
 * pass, so a new restaurant can set up its profile and menu while an admin
 * reviews it. Suspended accounts never pass.
 */
class EnsureAccountIsActive
{
    public function handle(Request $request, Closure $next, string ...$options): Response
    {
        $pendingAllowed = in_array('pending-ok', $options, true);

        return match ($request->user()?->status) {
            AccountStatus::Pending => $pendingAllowed ? $next($request) : $this->deny(
                'Tu cuenta está en revisión. Te avisaremos cuando esté aprobada.',
                'account_pending',
            ),
            AccountStatus::Suspended => $this->deny(
                'Tu cuenta fue suspendida. Contacta a soporte.',
                'account_suspended',
            ),
            default => $next($request),
        };
    }

    private function deny(string $message, string $code): JsonResponse
    {
        return response()->json(['message' => $message, 'code' => $code], 403);
    }
}
