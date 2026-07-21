<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Models\User;
use App\Models\Company;
use App\Models\FeatureFlag;
use App\Services\JwtAuthService;
use App\Services\OtpService;
use App\Services\TenantManager;
use App\Http\Requests\Api\V1\RegisterRequest;
use App\Http\Resources\Api\V1\UserResource;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;

class AuthController extends Controller
{
    protected JwtAuthService $jwtService;

    public function __construct(
        JwtAuthService $jwtService,
        private readonly OtpService $otpService,
    )
    {
        $this->jwtService = $jwtService;
    }

    public function login(Request $request)
    {
        $identifier = trim((string) $request->input(
            'identifier',
            $request->input('email', '')
        ));
        $password = (string) $request->input('password', '');

        if ($identifier === '' || $password === '') {
            return response()->json([
                'success' => false,
                'message' => 'Validation failed.',
                'data' => null,
                'meta' => null,
                'errors' => [
                    'identifier' => ['An email address or phone number is required.'],
                    'password' => ['The password field is required.'],
                ],
            ], 422);
        }
        
        try {
            $user = filter_var($identifier, FILTER_VALIDATE_EMAIL)
                ? User::withoutGlobalScopes()->where('email', $identifier)->first()
                : $this->otpService->findUserByPhone($identifier);
        } catch (\InvalidArgumentException) {
            $user = null;
        }

        if (!$user || !Hash::check($password, $user->password)) {
            return response()->json([
                'success' => false,
                'message' => 'Invalid credentials.',
                'data' => null,
                'meta' => null,
                'errors' => ['identifier' => ['The provided credentials do not match our records.']]
            ], 422);
        }

        if ($user->status === 'pending') {
            return response()->json([
                'success' => false,
                'message' => 'Your account is waiting for administrator approval.',
                'data' => null,
                'meta' => null,
                'errors' => ['status' => ['An administrator must approve your account before you can sign in.']]
            ], 403);
        }

        if ($user->status !== 'active') {
            return response()->json([
                'success' => false,
                'message' => 'Your account is suspended or inactive.',
                'data' => null,
                'meta' => null,
                'errors' => ['status' => ['Account is not active.']]
            ], 403);
        }

        return $this->tokenResponse($user, 'Login successful.');
    }

    public function config()
    {
        $companyId = config('services.registration.company_id');
        $companyExists = $companyId && Company::query()
            ->whereKey($companyId)
            ->where('status', 'active')
            ->exists();

        $otpEnabled = false;
        if ($companyExists) {
            $flag = FeatureFlag::withoutGlobalScopes()
                ->where('company_id', $companyId)
                ->where('key', 'otp_login')
                ->first();
            $otpEnabled = (bool) ($flag?->is_enabled ?? true);
        }

        return response()->json([
            'success' => true,
            'message' => 'Authentication configuration retrieved.',
            'data' => [
                'otp_login_enabled' => $otpEnabled,
            ],
            'meta' => null,
            'errors' => null,
        ]);
    }

    public function requestOtp(Request $request)
    {
        $data = $request->validate([
            'phone' => ['required', 'string', 'max:30'],
            'channel' => ['nullable', 'in:sms,whatsapp'],
        ]);

        try {
            $challenge = $this->otpService->request(
                $data['phone'],
                $data['channel'] ?? env('OTP_DEFAULT_CHANNEL', 'sms'),
                $request->ip(),
            );
        } catch (\RuntimeException|\InvalidArgumentException $error) {
            if ($error->getMessage() === 'If this phone is registered, an OTP will be sent.') {
                return response()->json([
                    'success' => true,
                    'message' => $error->getMessage(),
                    'data' => null,
                    'meta' => null,
                    'errors' => null,
                ]);
            }

            return response()->json([
                'success' => false,
                'message' => $error->getMessage(),
                'data' => null,
                'meta' => null,
                'errors' => ['phone' => [$error->getMessage()]],
            ], 422);
        }

        return response()->json([
            'success' => true,
            'message' => 'OTP sent.',
            'data' => [
                'challenge_id' => $challenge->id,
                'channel' => $challenge->channel,
                'expires_at' => $challenge->expires_at?->toIso8601String(),
            ],
            'meta' => null,
            'errors' => null,
        ]);
    }

    public function verifyOtp(Request $request)
    {
        $data = $request->validate([
            'phone' => ['required', 'string', 'max:30'],
            'channel' => ['nullable', 'in:sms,whatsapp'],
            'code' => ['required', 'digits:6'],
        ]);

        try {
            $user = $this->otpService->verify(
                $data['phone'],
                $data['channel'] ?? env('OTP_DEFAULT_CHANNEL', 'sms'),
                $data['code'],
            );
        } catch (\RuntimeException|\InvalidArgumentException $error) {
            return response()->json([
                'success' => false,
                'message' => $error->getMessage(),
                'data' => null,
                'meta' => null,
                'errors' => ['code' => [$error->getMessage()]],
            ], 422);
        }

        return $this->tokenResponse($user, 'OTP verified.');
    }

    public function register(RegisterRequest $request)
    {
        $data = $request->validated();

        try {
            $phoneInUse = !empty($data['phone'])
                && $this->otpService->phoneInUse($data['phone']);
        } catch (\InvalidArgumentException $error) {
            return response()->json([
                'success' => false,
                'message' => $error->getMessage(),
                'data' => null,
                'meta' => null,
                'errors' => ['phone' => [$error->getMessage()]],
            ], 422);
        }

        if ($phoneInUse) {
            return response()->json([
                'success' => false,
                'message' => 'This phone number is already registered.',
                'data' => null,
                'meta' => null,
                'errors' => ['phone' => ['This phone number is already registered.']],
            ], 422);
        }

        return DB::transaction(function () use ($data) {
            $companyId = null;
            $salesRep = null;

            if (!empty($data['referral_code'])) {
                // Registering under an existing company (via referral code from a Sales Rep)
                $salesRep = User::withoutGlobalScopes()
                    ->where('role', 'sales_rep')
                    ->where('id', $data['referral_code'])
                    ->first();
                
                if (!$salesRep) {
                    $salesRep = User::withoutGlobalScopes()
                        ->where('metadata->referral_code', $data['referral_code'])
                        ->first();
                }

                if (!$salesRep) {
                    return response()->json([
                        'success' => false,
                        'message' => 'Invalid referral code.',
                        'data' => null,
                        'meta' => null,
                        'errors' => ['referral_code' => ['The provided referral code is invalid.']]
                    ], 422);
                }

                $companyId = $salesRep->company_id;
            } else {
                $companyId = config('services.registration.company_id');

                $companyExists = $companyId && Company::query()
                    ->whereKey($companyId)
                    ->where('status', 'active')
                    ->exists();

                if (!$companyExists) {
                    return response()->json([
                        'success' => false,
                        'message' => 'Retailer registration is temporarily unavailable.',
                        'data' => null,
                        'meta' => null,
                        'errors' => [
                            'registration' => ['The primary company is not configured.'],
                        ],
                    ], 503);
                }
            }

            // Temporarily set tenant context for creation
            TenantManager::setCompanyId($companyId);

            $user = User::create([
                'id' => (string) Str::ulid(),
                'company_id' => $companyId,
                'name' => $data['name'],
                'email' => $data['email'] ?? null,
                'password' => Hash::make($data['password']),
                'role' => 'retailer',
                'status' => 'pending',
                'metadata' => [
                    'phone' => $data['phone'] ?? null,
                    'responsible_id' => $salesRep?->id,
                    'shop_name' => $data['company_name'] ?? $data['name'],
                ],
                'latitude' => $data['latitude'] ?? null,
                'longitude' => $data['longitude'] ?? null,
                'address' => $data['address'] ?? null,
            ]);

            return response()->json([
                'success' => true,
                'message' => 'Registration submitted. An administrator must approve your account before you can sign in.',
                'data' => [
                    'approval_required' => true,
                    'user' => new UserResource($user),
                ],
                'meta' => null,
                'errors' => null
            ], 201);
        });
    }

    public function me(Request $request)
    {
        return response()->json([
            'success' => true,
            'message' => 'User profile retrieved.',
            'data' => new UserResource(auth()->user()),
            'meta' => null,
            'errors' => null
        ]);
    }

    public function refresh(Request $request)
    {
        $refreshToken = $request->input('refresh_token');

        if (!$refreshToken) {
            return response()->json([
                'success' => false,
                'message' => 'Refresh token required.',
                'data' => null,
                'meta' => null,
                'errors' => ['refresh_token' => ['The refresh_token field is required.']]
            ], 422);
        }

        $payload = $this->jwtService->decode($refreshToken);

        if (!$payload || empty($payload['sub']) || (isset($payload['type']) && $payload['type'] !== 'refresh')) {
            return response()->json([
                'success' => false,
                'message' => 'Invalid refresh token.',
                'data' => null,
                'meta' => null,
                'errors' => ['refresh_token' => ['The refresh token is invalid or expired.']]
            ], 401);
        }

        $user = User::withoutGlobalScopes()->find($payload['sub']);

        if (!$user || $user->status !== 'active') {
            return response()->json([
                'success' => false,
                'message' => 'User not found or inactive.',
                'data' => null,
                'meta' => null,
                'errors' => ['user' => ['The user associated with this token is no longer active.']]
            ], 401);
        }

        $newAccessToken = $this->jwtService->encode([
            'sub' => $user->id,
            'type' => 'access',
            'role' => $user->role,
            'company_id' => $user->company_id,
        ], 3600);

        return response()->json([
            'success' => true,
            'message' => 'Token refreshed successfully.',
            'data' => [
                'access_token' => $newAccessToken,
                'token_type' => 'Bearer',
                'expires_in' => 3600,
            ],
            'meta' => null,
            'errors' => null
        ]);
    }

    public function logout()
    {
        return response()->json([
            'success' => true,
            'message' => 'Logout successful.',
            'data' => null,
            'meta' => null,
            'errors' => null
        ]);
    }

    private function tokenResponse(User $user, string $message)
    {
        $accessToken = $this->jwtService->encode([
            'sub' => $user->id,
            'type' => 'access',
            'role' => $user->role,
            'company_id' => $user->company_id,
        ], 3600);

        $refreshToken = $this->jwtService->encode([
            'sub' => $user->id,
            'type' => 'refresh',
        ], 86400 * 60);

        return response()->json([
            'success' => true,
            'message' => $message,
            'data' => [
                'access_token' => $accessToken,
                'refresh_token' => $refreshToken,
                'token_type' => 'Bearer',
                'expires_in' => 3600,
                'user' => new UserResource($user),
            ],
            'meta' => null,
            'errors' => null
        ]);
    }
}
