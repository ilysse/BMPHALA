<?php

namespace App\Http\Resources\Api\V1;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

class OrderResource extends JsonResource
{
    /**
     * Transform the resource into an array.
     *
     * @return array<string, mixed>
     */
    public function toArray(Request $request): array
    {
        $paidAmount = isset($this->paid_amount)
            ? (float) $this->paid_amount
            : (float) $this->payments()
                ->where('payment_status', 'completed')
                ->sum('amount');

        return [
            'id'               => $this->id,
            'order_number'     => $this->order_number,
            'retailer_id'      => $this->retailer_id,
            'distributor_id'   => $this->distributor_id,
            'status'           => $this->status,
            'payment_status'   => $this->payment_status,
            'subtotal'         => $this->total_amount,
            'discount_amount'  => $this->discount_amount,
            'tax_amount'       => $this->tax_amount,
            'total_amount'     => $this->total_amount,
            'shipping_amount'  => $this->shipping_amount,
            'grand_total'      => $this->grand_total,
            'paid_amount'      => round($paidAmount, 2),
            'delivery_address' => $this->delivery_address ?: $this->retailer?->address,
            'delivery_latitude' => $this->delivery_latitude ?? $this->retailer?->latitude,
            'delivery_longitude' => $this->delivery_longitude ?? $this->retailer?->longitude,
            'delivery_signature_url' => $this->delivery_signature_url,
            'delivery_photo_url' => $this->delivery_photo_url,
            'expected_delivery_at' => $this->expected_delivery_at?->toIso8601String(),
            'actual_delivery_at' => $this->actual_delivery_at?->toIso8601String(),
            'notes'            => $this->notes,
            'retailer'         => new UserResource($this->whenLoaded('retailer')),
            'customer'         => new UserResource($this->whenLoaded('retailer')),
            'distributor'      => new UserResource($this->whenLoaded('distributor')),
            'items'            => OrderItemResource::collection($this->whenLoaded('items')),
            'created_at'       => $this->created_at?->toIso8601String(),
        ];
    }
}
