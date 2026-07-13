<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Concerns\HasUlids;
use Illuminate\Database\Eloquent\Model;

class OutboundMessage extends Model
{
    use HasUlids;

    protected $fillable = [
        'channel',
        'to_phone',
        'body',
        'status',
        'provider',
        'provider_reference',
        'error',
        'available_at',
        'sent_at',
        'delivered_at',
        'metadata',
    ];

    protected function casts(): array
    {
        return [
            'available_at' => 'datetime',
            'sent_at' => 'datetime',
            'delivered_at' => 'datetime',
            'metadata' => 'array',
        ];
    }
}
