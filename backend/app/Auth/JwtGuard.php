<?php

namespace App\Auth;

use Illuminate\Contracts\Auth\Guard;
use Illuminate\Contracts\Auth\UserProvider;
use Illuminate\Contracts\Auth\Authenticatable;
use Illuminate\Http\Request;
use App\Services\JwtAuthService;
use App\Services\TenantManager;

class JwtGuard implements Guard
{
    use \Illuminate\Auth\GuardHelpers;

    protected Request $request;
    protected JwtAuthService $jwtService;

    public function __construct(UserProvider $provider, Request $request, JwtAuthService $jwtService)
    {
        $this->provider = $provider;
        $this->request = $request;
        $this->jwtService = $jwtService;
    }

    /**
     * Get the currently authenticated user.
     */
    public function user()
    {
        if ($this->user !== null) {
            return $this->user;
        }

        $token = $this->getTokenFromRequest();
        if (!$token) {
            return null;
        }

        $payload = $this->jwtService->decode($token);
        if (!$payload || empty($payload['sub'])) {
            return null;
        }

        if (!empty($payload['company_id'])) {
            TenantManager::setCompanyId($payload['company_id']);
        }

        $user = $this->provider->retrieveById($payload['sub']);
        if ($user) {
            $this->user = $user;
            // Set the tenant context dynamically based on the authenticated user's company_id
            TenantManager::setCompanyId($user->company_id);
        }

        return $this->user;
    }

    /**
     * Validate a user's credentials.
     */
    public function validate(array $credentials = [])
    {
        if (empty($credentials['email']) || empty($credentials['password'])) {
            return false;
        }

        $user = $this->provider->retrieveByCredentials($credentials);
        if ($user && $this->provider->validateCredentials($user, $credentials)) {
            return true;
        }

        return false;
    }

    /**
     * Get the token from the request header or query parameter.
     */
    protected function getTokenFromRequest(): ?string
    {
        $header = $this->request->header('Authorization', '');
        if (str_starts_with($header, 'Bearer ')) {
            return substr($header, 7);
        }
        return $this->request->query('token');
    }
}
