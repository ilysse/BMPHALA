<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Models\DeviceToken;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class DeviceTokenController extends Controller
{
    public function store(Request $request): JsonResponse
    {
        $data = $request->validate([
            'token' => ['required', 'string', 'max:512'],
            'platform' => ['required', 'in:android,ios,web'],
        ]);
        $user = $request->user();

        $device = DeviceToken::withoutGlobalScopes()->updateOrCreate(
            ['token' => $data['token']],
            [
                'company_id' => $user->company_id,
                'user_id' => $user->id,
                'platform' => $data['platform'],
                'last_seen_at' => now(),
            ],
        );

        return response()->json([
            'success' => true,
            'message' => 'Device registered for push notifications.',
            'data' => ['id' => $device->id],
            'meta' => null,
            'errors' => null,
        ]);
    }

    public function destroy(Request $request): JsonResponse
    {
        $data = $request->validate([
            'token' => ['required', 'string', 'max:512'],
        ]);

        DeviceToken::withoutGlobalScopes()
            ->where('user_id', $request->user()->id)
            ->where('token', $data['token'])
            ->delete();

        return response()->json([
            'success' => true,
            'message' => 'Device unregistered.',
            'data' => null,
            'meta' => null,
            'errors' => null,
        ]);
    }
}
