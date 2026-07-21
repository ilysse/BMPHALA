<?php

namespace App\Models;

use App\Traits\Multitenant;
use Illuminate\Database\Eloquent\Model;

class DispatchBatch extends Model
{
    use Multitenant;

    protected $fillable = [
        'company_id',
        'distributor_id',
        'created_by',
        'zone_geojson',
        'status',
    ];

    protected $casts = [
        'zone_geojson' => 'array',
    ];

    public function distributor()
    {
        return $this->belongsTo(User::class, 'distributor_id');
    }

    public function creator()
    {
        return $this->belongsTo(User::class, 'created_by');
    }

    public function orders()
    {
        return $this->belongsToMany(Order::class, 'dispatch_batch_order', 'dispatch_batch_id', 'order_id')
            ->withPivot('company_id');
    }
}
