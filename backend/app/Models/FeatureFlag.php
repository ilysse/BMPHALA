<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use App\Traits\Multitenant;

class FeatureFlag extends Model
{
    use Multitenant;

    protected $fillable = [
        'company_id',
        'key',
        'name',
        'is_enabled',
    ];

    protected $casts = [
        'is_enabled' => 'boolean',
    ];
}
