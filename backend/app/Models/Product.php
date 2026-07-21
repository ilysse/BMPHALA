<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use App\Traits\Multitenant;

class Product extends Model
{
    use Multitenant;

    protected $fillable = [
        'company_id',
        'category_id',
        'brand_id',
        'name',
        'sku',
        'barcode',
        'description',
        'image_url',
        'price',
        'cost_price',
        'pack_size',
        'pack_unit',
        'is_active',
    ];

    protected $casts = [
        'price' => 'decimal:2',
        'cost_price' => 'decimal:2',
        'pack_size' => 'integer',
        'is_active' => 'boolean',
    ];

    public function category()
    {
        return $this->belongsTo(Category::class);
    }

    public function brand()
    {
        return $this->belongsTo(Brand::class);
    }

    public function inventory()
    {
        return $this->hasMany(Inventory::class);
    }

    public function stockMovements()
    {
        return $this->hasMany(StockMovement::class);
    }

    public function getImageUrlAttribute($value)
    {
        if (empty($value)) return null;
        if (str_starts_with($value, 'http')) {
            return str_replace('/storage/', '/api/v1/images?path=', $value);
        }
        return url('api/v1/images?path=' . urlencode($value));
    }
}
