<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use App\Traits\Multitenant;

class Payment extends Model
{
    use Multitenant;

    protected $fillable = [
        'company_id',
        'order_id',
        'amount',
        'payment_method',
        'payment_status',
        'transaction_reference',
        'notes',
    ];

    protected $casts = [
        'amount' => 'decimal:2',
    ];

    public function order()
    {
        return $this->belongsTo(Order::class);
    }
}
