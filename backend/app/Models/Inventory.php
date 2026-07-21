<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use App\Traits\Multitenant;

class Inventory extends Model
{
    use Multitenant;

    protected $table = 'inventory';

    protected $fillable = [
        'company_id',
        'product_id',
        'warehouse_id',
        'quantity',
        'min_stock',
        'max_stock',
    ];

    protected $casts = [
        'quantity' => 'integer',
        'min_stock' => 'integer',
        'max_stock' => 'integer',
    ];

    public function product()
    {
        return $this->belongsTo(Product::class);
    }

    public function warehouse()
    {
        return $this->belongsTo(Warehouse::class);
    }
}
