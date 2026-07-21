<?php

namespace App\Services;

use App\Models\OutboundMessage;
use Illuminate\Support\Facades\Http;

class WhatsAppCloudProvider implements OtpMessageProvider
{
    public function __construct(private readonly DatabaseGatewayProvider $fallback)
    {
    }

    public function send(string $channel, string $phone, string $body, array $metadata = []): OutboundMessage
    {
        $token = env('WHATSAPP_ACCESS_TOKEN');
        $phoneNumberId = env('WHATSAPP_PHONE_NUMBER_ID');

        if ($channel !== 'whatsapp' || empty($token) || empty($phoneNumberId)) {
            return $this->fallback->send($channel, $phone, $body, $metadata);
        }

        $message = OutboundMessage::create([
            'channel' => $channel,
            'to_phone' => $phone,
            'body' => $body,
            'status' => 'pending',
            'provider' => 'whatsapp_cloud',
            'available_at' => now(),
            'metadata' => $metadata,
        ]);

        $response = Http::withToken($token)
            ->acceptJson()
            ->post("https://graph.facebook.com/v20.0/{$phoneNumberId}/messages", [
                'messaging_product' => 'whatsapp',
                'to' => ltrim($phone, '+'),
                'type' => 'text',
                'text' => ['body' => $body],
            ]);

        if ($response->successful()) {
            $message->update([
                'status' => 'sent',
                'provider_reference' => $response->json('messages.0.id'),
                'sent_at' => now(),
            ]);

            return $message->fresh();
        }

        $message->update([
            'status' => 'failed',
            'error' => $response->body(),
        ]);

        return $message->fresh();
    }
}
