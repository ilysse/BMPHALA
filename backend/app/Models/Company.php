<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Support\Str;

class Company extends Model
{
    public $incrementing = false;
    protected $keyType = 'string';

    protected $fillable = [
        'name',
        'email',
        'phone',
        'tax_id',
        'logo_url',
        'address',
        'status',
    ];

    protected static function boot()
    {
        parent::boot();
        static::creating(function ($model) {
            if (empty($model->id)) {
                $model->id = (string) Str::ulid();
            }
        });
    }

    public function users()
    {
        return $this->hasMany(User::class);
    }

    public function getLogoUrlAttribute($value)
    {
        if (empty($value)) return null;
        if (str_starts_with($value, 'http')) {
            return str_replace('/storage/', '/api/v1/images?path=', $value);
        }
        return url('api/v1/images?path=' . urlencode($value));
    }
}
