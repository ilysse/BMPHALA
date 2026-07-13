<?php

namespace App\Jobs;

use App\Services\FcmService;
use Illuminate\Contracts\Queue\ShouldQueue;
use Illuminate\Foundation\Queue\Queueable;

class SendPushNotification implements ShouldQueue
{
    use Queueable;

    public int $tries = 3;

    public function __construct(
        public readonly string $userId,
        public readonly string $title,
        public readonly string $body,
        public readonly array $data = [],
    ) {
        $this->afterCommit();
    }

    public function handle(FcmService $fcm): void
    {
        $fcm->sendToUser(
            $this->userId,
            $this->title,
            $this->body,
            $this->data,
        );
    }
}
