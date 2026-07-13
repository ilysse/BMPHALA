<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use App\Traits\Multitenant;

class Invoice extends Model
{
    use Multitenant;

    protected $fillable = [
        'company_id',
        'order_id',
        'invoice_number',
        'amount_due',
        'due_date',
        'status',
    ];

    protected $casts = [
        'amount_due' => 'decimal:2',
        'due_date' => 'datetime',
    ];

    public function order()
    {
        return $this->belongsTo(Order::class);
    }

    public function company()
    {
        return $this->belongsTo(\App\Models\Company::class);
    }
}
