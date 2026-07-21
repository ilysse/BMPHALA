<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Models\FeatureFlag;
use Illuminate\Http\Request;
use Illuminate\Support\Str;

class FeatureFlagController extends Controller
{
    public function index()
    {
        abort_unless(auth()->user()?->role === 'admin', 403, 'Only admins can manage feature flags.');

        FeatureFlag::firstOrCreate(
            ['key' => 'otp_login'],
            [
                'id' => (string) Str::ulid(),
                'name' => 'OTP Login',
                'is_enabled' => true,
            ]
        );

        $flags = FeatureFlag::all();
        return response()->json([
            'success' => true,
            'message' => 'Feature flags retrieved.',
            'data' => $flags,
            'meta' => null,
            'errors' => null
        ]);
    }

    public function toggle(Request $request, $key)
    {
        abort_unless(auth()->user()?->role === 'admin', 403, 'Only admins can manage feature flags.');

        $flag = FeatureFlag::firstOrCreate(
            ['key' => $key],
            [
                'id' => (string) Str::ulid(),
                'name' => Str::headline(str_replace(['-', '_'], ' ', $key)),
                'is_enabled' => false,
            ]
        );

        $flag->is_enabled = !$flag->is_enabled;
        $flag->save();

        return response()->json([
            'success' => true,
            'message' => "Feature flag '{$key}' toggled.",
            'data' => $flag,
            'meta' => null,
            'errors' => null
        ]);
    }

    public function update(Request $request, string $key)
    {
        abort_unless(auth()->user()?->role === 'admin', 403, 'Only admins can manage feature flags.');

        $data = $request->validate([
            'is_enabled' => ['required', 'boolean'],
        ]);

        $flag = FeatureFlag::firstOrCreate(
            ['key' => $key],
            [
                'id' => (string) Str::ulid(),
                'name' => Str::headline(str_replace(['-', '_'], ' ', $key)),
                'is_enabled' => true,
            ]
        );
        $flag->is_enabled = (bool) $data['is_enabled'];
        $flag->save();

        return response()->json([
            'success' => true,
            'message' => "Feature flag '{$key}' updated.",
            'data' => $flag,
            'meta' => null,
            'errors' => null,
        ]);
    }
}
