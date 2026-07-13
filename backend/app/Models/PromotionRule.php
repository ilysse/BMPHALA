<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use App\Traits\Multitenant;

class PromotionRule extends Model
{
    use Multitenant;

    protected $fillable = [
        'company_id',
        'name',
        'description',
        'type', // percentage, fixed, bulk_tier, buy_x_get_y
        'is_active',
        'start_date',
        'end_date',
        'configuration',
        'priority',
    ];

    protected $casts = [
        'is_active' => 'boolean',
        'start_date' => 'datetime',
        'end_date' => 'datetime',
        'configuration' => 'array',
        'priority' => 'integer',
    ];
}
