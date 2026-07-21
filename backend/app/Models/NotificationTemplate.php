<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use App\Traits\Multitenant;

class NotificationTemplate extends Model
{
    use Multitenant;

    protected $fillable = [
        'company_id',
        'event_type',
        'title_template',
        'body_template',
        'channel',
        'is_active',
    ];

    protected $casts = [
        'is_active' => 'boolean',
    ];
}
