<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use App\Traits\Multitenant;

class OrderHistory extends Model
{
    use Multitenant;

    protected $table = 'order_history';

    protected $fillable = [
        'company_id',
        'order_id',
        'status',
        'changed_by',
        'notes',
    ];

    public function order()
    {
        return $this->belongsTo(Order::class);
    }

    public function user()
    {
        return $this->belongsTo(User::class, 'changed_by');
    }
}
