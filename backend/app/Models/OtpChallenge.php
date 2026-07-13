<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Concerns\HasUlids;
use Illuminate\Database\Eloquent\Model;

class OtpChallenge extends Model
{
    use HasUlids;

    protected $fillable = [
        'company_id',
        'phone',
        'normalized_phone',
        'channel',
        'purpose',
        'code_hash',
        'expires_at',
        'consumed_at',
        'attempts',
        'resend_count',
        'ip_address',
        'metadata',
    ];

    protected function casts(): array
    {
        return [
            'expires_at' => 'datetime',
            'consumed_at' => 'datetime',
            'metadata' => 'array',
        ];
    }
}
