<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use App\Traits\Multitenant;

class Order extends Model
{
    use Multitenant;

    protected $fillable = [
        'company_id',
        'order_number',
        'retailer_id',
        'distributor_id',
        'status',
        'payment_status',
        'total_amount',
        'discount_amount',
        'tax_amount',
        'shipping_amount',
        'grand_total',
        'notes',
        'delivery_address',
        'delivery_gps',
        'delivery_latitude',
        'delivery_longitude',
        'delivery_signature_url',
        'delivery_photo_url',
        'expected_delivery_at',
        'actual_delivery_at',
    ];

    protected $casts = [
        'total_amount' => 'decimal:2',
        'discount_amount' => 'decimal:2',
        'tax_amount' => 'decimal:2',
        'shipping_amount' => 'decimal:2',
        'grand_total' => 'decimal:2',
        'delivery_latitude' => 'decimal:7',
        'delivery_longitude' => 'decimal:7',
        'expected_delivery_at' => 'datetime',
        'actual_delivery_at' => 'datetime',
    ];

    public function retailer()
    {
        return $this->belongsTo(User::class, 'retailer_id');
    }

    public function distributor()
    {
        return $this->belongsTo(User::class, 'distributor_id');
    }

    public function items()
    {
        return $this->hasMany(OrderItem::class);
    }

    public function history()
    {
        return $this->hasMany(OrderHistory::class);
    }

    public function payments()
    {
        return $this->hasMany(Payment::class);
    }

    public function invoice()
    {
        return $this->hasOne(Invoice::class);
    }

    /**
     * Transition the order to a new status.
     */
    public function transitionTo(string $status, ?string $reason = null, ?User $user = null): void
    {
        $transitions = [
            'pending' => ['confirmed', 'cancelled'],
            'confirmed' => ['processing', 'cancelled'],
            'processing' => ['assigned', 'cancelled'],
            'assigned' => ['in_transit', 'cancelled'],
            'in_transit' => ['out_for_delivery', 'cancelled'],
            'out_for_delivery' => ['delivered', 'cancelled'],
            'delivered' => ['returned'],
            'cancelled' => [],
            'returned' => [],
        ];

        $currentStatus = $this->status ?: 'pending';

        if (!in_array($status, $transitions[$currentStatus] ?? [])) {
            throw new \InvalidArgumentException("Invalid status transition from {$currentStatus} to {$status}");
        }

        $this->status = $status;
        if ($status === 'delivered') {
            $this->actual_delivery_at = now();
        }
        $this->save();

        // Log to history
        $this->history()->create([
            'company_id' => $this->company_id,
            'status' => $status,
            'changed_by' => $user ? $user->id : (auth()->id() ?: $this->retailer_id),
            'notes' => $reason ?: "Status transitioned to {$status}",
        ]);
    }

    public function getDeliverySignatureUrlAttribute($value)
    {
        if (empty($value)) return null;
        if (str_starts_with($value, 'http')) {
            return str_replace('/storage/', '/api/v1/images?path=', $value);
        }
        return url('api/v1/images?path=' . urlencode($value));
    }

    public function getDeliveryPhotoUrlAttribute($value)
    {
        if (empty($value)) return null;
        if (str_starts_with($value, 'http')) {
            return str_replace('/storage/', '/api/v1/images?path=', $value);
        }
        return url('api/v1/images?path=' . urlencode($value));
    }
}
