<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Models\OutboundMessage;
use Illuminate\Http\Request;

class SmsGatewayController extends Controller
{
    public function next(Request $request)
    {
        $this->authorizeGateway($request);

        $message = OutboundMessage::query()
            ->where('channel', 'sms')
            ->where('status', 'pending')
            ->where(function ($query) {
                $query->whereNull('available_at')
                    ->orWhere('available_at', '<=', now());
            })
            ->oldest()
            ->first();

        if (!$message) {
            return response()->json([
                'success' => true,
                'message' => 'No pending messages.',
                'data' => null,
                'meta' => null,
                'errors' => null,
            ]);
        }

        $message->update(['status' => 'sending']);

        return response()->json([
            'success' => true,
            'message' => 'Message claimed.',
            'data' => [
                'id' => $message->id,
                'to_phone' => $message->to_phone,
                'body' => $message->body,
            ],
            'meta' => null,
            'errors' => null,
        ]);
    }

    public function status(Request $request, string $id)
    {
        $this->authorizeGateway($request);

        $data = $request->validate([
            'status' => ['required', 'in:sent,failed,delivered'],
            'provider_reference' => ['nullable', 'string', 'max:255'],
            'error' => ['nullable', 'string', 'max:1000'],
        ]);

        $message = OutboundMessage::findOrFail($id);
        $updates = [
            'status' => $data['status'],
            'provider_reference' => $data['provider_reference'] ?? $message->provider_reference,
            'error' => $data['error'] ?? null,
        ];

        if ($data['status'] === 'sent') {
            $updates['sent_at'] = now();
        }
        if ($data['status'] === 'delivered') {
            $updates['sent_at'] = $message->sent_at ?? now();
            $updates['delivered_at'] = now();
        }

        $message->update($updates);

        return response()->json([
            'success' => true,
            'message' => 'Gateway status recorded.',
            'data' => $message->fresh(),
            'meta' => null,
            'errors' => null,
        ]);
    }

    private function authorizeGateway(Request $request): void
    {
        $expected = env('SMS_GATEWAY_TOKEN', 'local-dev-token');
        $provided = (string) $request->header('X-Gateway-Token', '');

        abort_unless($expected !== '' && hash_equals($expected, $provided), 401, 'Invalid gateway token.');
    }
}
