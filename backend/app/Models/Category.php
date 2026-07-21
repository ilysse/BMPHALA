<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use App\Traits\Multitenant;

class Category extends Model
{
    use Multitenant;

    protected $fillable = ['company_id', 'name', 'slug', 'description', 'parent_id', 'image_url', 'sort_order', 'is_active'];

    public function products()
    {
        return $this->hasMany(Product::class);
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
