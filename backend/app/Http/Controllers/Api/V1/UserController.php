<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Models\User;
use App\Models\Order;
use App\Models\AuditLog;
use App\Http\Resources\Api\V1\UserResource;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Str;

class UserController extends Controller
{
    public function index(Request $request)
    {
        $query = User::query();

        if ($request->filled('role')) {
            $query->where('role', $request->role);
        }

        if ($request->filled('status')) {
            $query->where('status', $request->status);
        }

        // If the user is a sales rep, they can only see retailers assigned to them
        $user = auth()->user();
        if ($user->role === 'sales_rep') {
            $query->where('role', 'retailer')
                  ->where('metadata->responsible_id', $user->id);
        }

        $users = $query->paginate($request->integer('per_page', 15));

        return response()->json([
            'success' => true,
            'message' => 'Users retrieved.',
            'data' => UserResource::collection($users->items()),
            'meta' => [
                'page' => $users->currentPage(),
                'per_page' => $users->perPage(),
                'total' => $users->total(),
                'last_page' => $users->lastPage(),
            ],
            'errors' => null
        ]);
    }

    public function store(Request $request)
    {
        $data = $request->validate([
            'name' => 'required|string|max:255',
            'email' => 'required|email|max:255',
            'password' => 'required|string|min:8',
            'role' => 'required|in:admin,distributor,retailer,sales_rep',
            'phone' => 'nullable|string',
            'latitude' => 'nullable|numeric|between:-90,90',
            'longitude' => 'nullable|numeric|between:-180,180',
            'address' => 'nullable|string|max:500',
            'can_collect_cash' => 'nullable|boolean',
            'representative_features' => 'nullable|array',
            'representative_features.dashboard' => 'nullable|boolean',
            'representative_features.retailers' => 'nullable|boolean',
            'representative_features.orders' => 'nullable|boolean',
            'representative_features.onboarding' => 'nullable|boolean',
        ]);

        // Check unique email scoped to company
        $exists = User::where('email', $data['email'])->exists();
        if ($exists) {
            return response()->json([
                'success' => false,
                'message' => 'Email already exists.',
                'data' => null,
                'meta' => null,
                'errors' => ['email' => ['The email has already been taken.']]
            ], 422);
        }

        $metadata = [
            'phone' => $data['phone'] ?? null,
        ];

        if ($data['role'] === 'sales_rep') {
            $metadata['referral_code'] = 'REP-' . strtoupper(Str::random(6));
        }

        if (array_key_exists('can_collect_cash', $data)) {
            $metadata['can_collect_cash'] = (bool) $data['can_collect_cash'];
        }

        if (isset($data['representative_features'])) {
            $metadata['representative_features'] = $this->normalizeRepresentativeFeatures(
                $data['representative_features']
            );
        }

        $user = User::create([
            'id' => (string) Str::ulid(),
            'company_id' => auth()->user()->company_id,
            'name' => $data['name'],
            'email' => $data['email'],
            'password' => Hash::make($data['password']),
            'role' => $data['role'],
            'status' => 'active',
            'metadata' => $metadata,
            'latitude' => $data['latitude'] ?? null,
            'longitude' => $data['longitude'] ?? null,
            'address' => $data['address'] ?? null,
        ]);

        return response()->json([
            'success' => true,
            'message' => 'User created successfully.',
            'data' => new UserResource($user),
            'meta' => null,
            'errors' => null
        ], 201);
    }

    public function show(User $user)
    {
        return response()->json([
            'success' => true,
            'message' => 'User retrieved.',
            'data' => new UserResource($user),
            'meta' => null,
            'errors' => null
        ]);
    }

    public function update(Request $request, User $user)
    {
        $data = $request->validate([
            'name' => 'sometimes|required|string|max:255',
            'email' => 'sometimes|required|email|max:255',
            'role' => 'sometimes|required|in:admin,distributor,retailer,sales_rep',
            'phone' => 'nullable|string',
            'latitude' => 'nullable|numeric|between:-90,90',
            'longitude' => 'nullable|numeric|between:-180,180',
            'address' => 'nullable|string|max:500',
            'can_collect_cash' => 'nullable|boolean',
            'representative_features' => 'nullable|array',
            'representative_features.dashboard' => 'nullable|boolean',
            'representative_features.retailers' => 'nullable|boolean',
            'representative_features.orders' => 'nullable|boolean',
            'representative_features.onboarding' => 'nullable|boolean',
            'status' => 'sometimes|required|in:active,inactive,pending',
        ]);

        if (isset($data['email']) && $data['email'] !== $user->email) {
            $exists = User::where('email', $data['email'])->exists();
            if ($exists) {
                return response()->json([
                    'success' => false,
                    'message' => 'Email already exists.',
                    'data' => null,
                    'meta' => null,
                    'errors' => ['email' => ['The email has already been taken.']]
                ], 422);
            }
            $user->email = $data['email'];
        }

        if (isset($data['name'])) {
            $user->name = $data['name'];
        }

        if (isset($data['role'])) {
            $user->role = $data['role'];
        }

        if (isset($data['status'])) {
            $user->status = $data['status'];
        }

        if (array_key_exists('latitude', $data)) {
            $user->latitude = $data['latitude'];
        }

        if (array_key_exists('longitude', $data)) {
            $user->longitude = $data['longitude'];
        }

        if (array_key_exists('address', $data)) {
            $user->address = $data['address'];
        }

        if (
            isset($data['phone']) ||
            array_key_exists('can_collect_cash', $data) ||
            isset($data['representative_features'])
        ) {
            $metadata = $user->metadata ?? [];
            if (isset($data['phone'])) {
                $metadata['phone'] = $data['phone'];
            }
            if (array_key_exists('can_collect_cash', $data)) {
                $metadata['can_collect_cash'] = (bool) $data['can_collect_cash'];
            }
            if (isset($data['representative_features'])) {
                $metadata['representative_features'] = $this->normalizeRepresentativeFeatures(
                    $data['representative_features'],
                    $metadata['representative_features'] ?? []
                );
            }
            $user->metadata = $metadata;
        }

        $user->save();

        if (
            $user->role === 'retailer' &&
            $user->latitude !== null &&
            $user->longitude !== null
        ) {
            Order::where('retailer_id', $user->id)
                ->whereNull('distributor_id')
                ->whereIn('status', ['pending', 'confirmed', 'processing'])
                ->where(function ($query) {
                    $query->whereNull('delivery_latitude')
                        ->orWhereNull('delivery_longitude');
                })
                ->update([
                    'delivery_latitude' => $user->latitude,
                    'delivery_longitude' => $user->longitude,
                    'delivery_address' => $user->address,
                    'delivery_gps' => "{$user->latitude},{$user->longitude}",
                ]);
        }

        return response()->json([
            'success' => true,
            'message' => 'User updated successfully.',
            'data' => new UserResource($user),
            'meta' => null,
            'errors' => null
        ]);
    }

    public function updateCashCollection(Request $request, string $id)
    {
        abort_unless(auth()->user()?->role === 'admin', 403, 'Only admins can update cash collection access.');

        $data = $request->validate([
            'can_collect_cash' => ['required', 'boolean'],
        ]);

        $user = User::withoutGlobalScopes()
            ->where('company_id', auth()->user()->company_id)
            ->whereIn('role', ['admin', 'sales_rep', 'distributor'])
            ->findOrFail($id);

        $metadata = $user->metadata ?? [];
        $metadata['can_collect_cash'] = (bool) $data['can_collect_cash'];
        $user->metadata = $metadata;
        $user->save();

        return response()->json([
            'success' => true,
            'message' => 'Cash collection access updated.',
            'data' => new UserResource($user),
            'meta' => null,
            'errors' => null,
        ]);
    }

    public function pendingRegistrations(Request $request)
    {
        abort_unless(auth()->user()?->role === 'admin', 403, 'Only admins can review registrations.');

        $query = User::withoutGlobalScopes()
            ->where('company_id', auth()->user()->company_id)
            ->where('role', 'retailer')
            ->where('status', 'pending')
            ->latest();

        if ($request->filled('search')) {
            $search = trim((string) $request->input('search'));
            $query->where(function ($builder) use ($search) {
                $builder->where('name', 'like', "%{$search}%")
                    ->orWhere('email', 'like', "%{$search}%")
                    ->orWhere('address', 'like', "%{$search}%")
                    ->orWhere('metadata', 'like', "%{$search}%");
            });
        }

        $perPage = max(1, min($request->integer('per_page', 25), 100));
        $users = $query->paginate($perPage);

        return response()->json([
            'success' => true,
            'message' => 'Pending registrations retrieved.',
            'data' => UserResource::collection($users->items()),
            'meta' => [
                'page' => $users->currentPage(),
                'per_page' => $users->perPage(),
                'total' => $users->total(),
                'last_page' => $users->lastPage(),
            ],
            'errors' => null,
        ]);
    }

    public function approve(Request $request, string $id)
    {
        abort_unless(auth()->user()?->role === 'admin', 403, 'Only admins can approve user accounts.');

        $user = User::withoutGlobalScopes()
            ->where('company_id', auth()->user()->company_id)
            ->findOrFail($id);

        $previousStatus = $user->status;
        $user->status = 'active';
        $user->save();

        if ($previousStatus !== 'active') {
            AuditLog::create([
                'company_id' => auth()->user()->company_id,
                'user_id' => auth()->id(),
                'event' => 'user.approved',
                'auditable_type' => User::class,
                'auditable_id' => $user->id,
                'old_values' => ['status' => $previousStatus],
                'new_values' => ['status' => 'active'],
                'ip_address' => $request->ip(),
                'user_agent' => $request->userAgent(),
            ]);
        }

        return response()->json([
            'success' => true,
            'message' => $previousStatus === 'active'
                ? 'User account is already active.'
                : 'User account approved successfully.',
            'data' => new UserResource($user),
            'meta' => null,
            'errors' => null,
        ]);
    }

    public function reject(Request $request, string $id)
    {
        abort_unless(auth()->user()?->role === 'admin', 403, 'Only admins can reject user accounts.');

        $data = $request->validate([
            'reason' => ['nullable', 'string', 'max:500'],
        ]);

        $user = User::withoutGlobalScopes()
            ->where('company_id', auth()->user()->company_id)
            ->where('role', 'retailer')
            ->findOrFail($id);

        if ($user->status !== 'pending') {
            return response()->json([
                'success' => false,
                'message' => 'Only pending registrations can be rejected.',
                'data' => null,
                'meta' => null,
                'errors' => ['status' => ['This registration is no longer pending.']],
            ], 422);
        }

        $metadata = $user->metadata ?? [];
        $metadata['registration_review'] = [
            'action' => 'rejected',
            'reason' => $data['reason'] ?? null,
            'reviewed_by' => auth()->id(),
            'reviewed_at' => now()->toIso8601String(),
        ];

        $user->status = 'inactive';
        $user->metadata = $metadata;
        $user->save();

        AuditLog::create([
            'company_id' => auth()->user()->company_id,
            'user_id' => auth()->id(),
            'event' => 'user.rejected',
            'auditable_type' => User::class,
            'auditable_id' => $user->id,
            'old_values' => ['status' => 'pending'],
            'new_values' => [
                'status' => 'inactive',
                'reason' => $data['reason'] ?? null,
            ],
            'ip_address' => $request->ip(),
            'user_agent' => $request->userAgent(),
        ]);

        return response()->json([
            'success' => true,
            'message' => 'Registration rejected.',
            'data' => new UserResource($user),
            'meta' => null,
            'errors' => null,
        ]);
    }

    public function updatePassword(Request $request, string $id)
    {
        abort_unless(auth()->user()?->role === 'admin', 403, 'Only admins can reset user passwords.');

        $data = $request->validate([
            'password' => ['required', 'string', 'min:8', 'confirmed'],
        ]);

        $user = User::withoutGlobalScopes()
            ->where('company_id', auth()->user()->company_id)
            ->findOrFail($id);

        $user->password = Hash::make($data['password']);
        $user->save();

        AuditLog::create([
            'company_id' => auth()->user()->company_id,
            'user_id' => auth()->id(),
            'event' => 'user.password_reset',
            'auditable_type' => User::class,
            'auditable_id' => $user->id,
            'new_values' => [
                'target_role' => $user->role,
            ],
            'ip_address' => $request->ip(),
            'user_agent' => $request->userAgent(),
        ]);

        return response()->json([
            'success' => true,
            'message' => 'Password updated successfully.',
            'data' => new UserResource($user),
            'meta' => null,
            'errors' => null,
        ]);
    }

    public function updateRepresentativeFeatures(Request $request, string $id)
    {
        abort_unless(auth()->user()?->role === 'admin', 403, 'Only admins can update representative features.');

        $data = $request->validate([
            'representative_features' => ['required', 'array'],
            'representative_features.dashboard' => ['nullable', 'boolean'],
            'representative_features.retailers' => ['nullable', 'boolean'],
            'representative_features.orders' => ['nullable', 'boolean'],
            'representative_features.onboarding' => ['nullable', 'boolean'],
        ]);

        $user = User::withoutGlobalScopes()
            ->where('company_id', auth()->user()->company_id)
            ->where('role', 'sales_rep')
            ->findOrFail($id);

        $metadata = $user->metadata ?? [];
        $metadata['representative_features'] = $this->normalizeRepresentativeFeatures(
            $data['representative_features'],
            $metadata['representative_features'] ?? []
        );
        $user->metadata = $metadata;
        $user->save();

        return response()->json([
            'success' => true,
            'message' => 'Representative features updated.',
            'data' => new UserResource($user),
            'meta' => null,
            'errors' => null,
        ]);
    }

    private function normalizeRepresentativeFeatures(array $features, array $existing = []): array
    {
        return [
            'dashboard' => (bool) ($features['dashboard'] ?? $existing['dashboard'] ?? true),
            'retailers' => (bool) ($features['retailers'] ?? $existing['retailers'] ?? true),
            'orders' => (bool) ($features['orders'] ?? $existing['orders'] ?? true),
            'onboarding' => (bool) ($features['onboarding'] ?? $existing['onboarding'] ?? true),
        ];
    }

    public function destroy(User $user)
    {
        if ($user->id === auth()->id()) {
            return response()->json([
                'success' => false,
                'message' => 'Cannot delete yourself.',
                'data' => null,
                'meta' => null,
                'errors' => null
            ], 422);
        }

        $user->delete();

        return response()->json([
            'success' => true,
            'message' => 'User deleted successfully.',
            'data' => null,
            'meta' => null,
            'errors' => null
        ]);
    }
}
