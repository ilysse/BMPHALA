<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use App\Traits\Multitenant;

class Warehouse extends Model
{
    use Multitenant;

    protected $fillable = ['company_id', 'name', 'location', 'is_active'];

    protected $casts = [
        'is_active' => 'boolean',
    ];

    public function inventory()
    {
        return $this->hasMany(Inventory::class);
    }
}
