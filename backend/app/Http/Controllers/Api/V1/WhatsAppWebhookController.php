<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Models\OutboundMessage;
use Illuminate\Http\Request;
use Illuminate\Http\Response;

class WhatsAppWebhookController extends Controller
{
    public function verify(Request $request)
    {
        $mode = $request->query('hub_mode', $request->query('hub.mode'));
        $token = $request->query('hub_verify_token', $request->query('hub.verify_token'));
        $challenge = $request->query('hub_challenge', $request->query('hub.challenge'));

        if ($mode === 'subscribe' && hash_equals((string) env('WHATSAPP_WEBHOOK_VERIFY_TOKEN'), (string) $token)) {
            return response($challenge, Response::HTTP_OK)->header('Content-Type', 'text/plain');
        }

        return response()->json([
            'success' => false,
            'message' => 'Webhook verification failed.',
            'data' => null,
            'meta' => null,
            'errors' => ['verify_token' => ['Invalid WhatsApp webhook verify token.']],
        ], Response::HTTP_FORBIDDEN);
    }

    public function receive(Request $request)
    {
        $payload = $request->all();

        foreach ($payload['entry'] ?? [] as $entry) {
            foreach ($entry['changes'] ?? [] as $change) {
                $value = $change['value'] ?? [];
                $this->recordStatuses($value['statuses'] ?? []);
                $this->recordInboundMessages($value['messages'] ?? [], $value['contacts'] ?? [], $value['metadata'] ?? []);
            }
        }

        return response()->json([
            'success' => true,
            'message' => 'WhatsApp webhook accepted.',
            'data' => null,
            'meta' => null,
            'errors' => null,
        ]);
    }

    private function recordStatuses(array $statuses): void
    {
        foreach ($statuses as $status) {
            $messageId = $status['id'] ?? null;
            if (!$messageId) {
                continue;
            }

            $updates = [
                'status' => $status['status'] ?? 'updated',
                'metadata' => ['webhook_status' => $status],
            ];

            if (($status['status'] ?? null) === 'sent') {
                $updates['sent_at'] = now();
            }

            if (($status['status'] ?? null) === 'delivered' || ($status['status'] ?? null) === 'read') {
                $updates['delivered_at'] = now();
            }

            OutboundMessage::where('provider_reference', $messageId)->update($updates);
        }
    }

    private function recordInboundMessages(array $messages, array $contacts, array $metadata): void
    {
        $contactMap = collect($contacts)->keyBy('wa_id');

        foreach ($messages as $message) {
            $messageId = $message['id'] ?? null;
            if (!$messageId || OutboundMessage::where('provider_reference', $messageId)->exists()) {
                continue;
            }

            $from = $message['from'] ?? '';
            $body = $message['text']['body']
                ?? $message['button']['text']
                ?? $message['interactive']['button_reply']['title']
                ?? $message['type']
                ?? 'WhatsApp message';

            OutboundMessage::create([
                'channel' => 'whatsapp',
                'to_phone' => $from,
                'body' => $body,
                'status' => 'received',
                'provider' => 'whatsapp_cloud',
                'provider_reference' => $messageId,
                'available_at' => now(),
                'metadata' => [
                    'direction' => 'inbound',
                    'contact' => $contactMap[$from] ?? null,
                    'phone_number_id' => $metadata['phone_number_id'] ?? null,
                    'raw' => $message,
                ],
            ]);
        }
    }
}
