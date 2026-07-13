<?php

namespace App\Services;

use App\Models\OutboundMessage;

interface OtpMessageProvider
{
    public function send(string $channel, string $phone, string $body, array $metadata = []): OutboundMessage;
}
