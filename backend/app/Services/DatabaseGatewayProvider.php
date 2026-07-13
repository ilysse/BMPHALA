<?php

namespace App\Services;

use App\Models\OutboundMessage;

class DatabaseGatewayProvider implements OtpMessageProvider
{
    public function send(string $channel, string $phone, string $body, array $metadata = []): OutboundMessage
    {
        return OutboundMessage::create([
            'channel' => $channel,
            'to_phone' => $phone,
            'body' => $body,
            'status' => 'pending',
            'provider' => 'database_gateway',
            'available_at' => now(),
            'metadata' => $metadata,
        ]);
    }
}
