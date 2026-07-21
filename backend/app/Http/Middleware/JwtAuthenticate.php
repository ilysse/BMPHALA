<?php

namespace App\Http\Middleware;

use Closure;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\Response;
use App\Services\JwtAuthService;
use App\Services\TenantManager;
use App\Models\User;

class JwtAuthenticate
{
    protected JwtAuthService $jwtService;

    public function __construct(JwtAuthService $jwtService)
    {
        $this->jwtService = $jwtService;
    }

    /**
     * Handle an incoming request.
     *
     * Checks for a valid Bearer JWT token, resolves the authenticated user,
     * and sets the tenant context. Returns 401 on failure.
     */
    public function handle(Request $request, Closure $next): Response
    {
        $header = $request->header('Authorization', '');

        if (!str_starts_with($header, 'Bearer ')) {
            return response()->json([
                'success' => false,
                'message' => 'Authentication required.',
                'data'    => null,
                'meta'    => null,
                'errors'  => ['token' => ['Missing or malformed Authorization header.']],
            ], 401);
        }

        $token = substr($header, 7);

        $payload = $this->jwtService->decode($token);

        if (!$payload || empty($payload['sub'])) {
            return response()->json([
                'success' => false,
                'message' => 'Invalid or expired token.',
                'data'    => null,
                'meta'    => null,
                'errors'  => ['token' => ['The provided token is invalid or has expired.']],
            ], 401);
        }

        // Ensure this is an access token, not a refresh token
        if (isset($payload['type']) && $payload['type'] !== 'access') {
            return response()->json([
                'success' => false,
                'message' => 'Invalid token type.',
                'data'    => null,
                'meta'    => null,
                'errors'  => ['token' => ['Refresh tokens cannot be used for API access.']],
            ], 401);
        }

        // Retrieve the user without tenant scoping (user may be from any company)
        $user = User::withoutGlobalScopes()->find($payload['sub']);

        if (!$user || $user->status !== 'active') {
            return response()->json([
                'success' => false,
                'message' => 'User not found or inactive.',
                'data'    => null,
                'meta'    => null,
                'errors'  => ['user' => ['The authenticated user could not be resolved.']],
            ], 401);
        }

        // Set the tenant context BEFORE setting the auth user
        TenantManager::setCompanyId($user->company_id);

        // Set the authenticated user on the guard
        auth()->setUser($user);

        return $next($request);
    }
}
