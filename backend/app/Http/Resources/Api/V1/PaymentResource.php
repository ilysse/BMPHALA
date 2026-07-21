<?php

namespace App\Http\Resources\Api\V1;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

class PaymentResource extends JsonResource
{
    /**
     * Transform the resource into an array.
     *
     * @return array<string, mixed>
     */
    public function toArray(Request $request): array
    {
        return [
            'id'                    => $this->id,
            'order_id'              => $this->order_id,
            'amount'                => $this->amount,
            'payment_method'        => $this->payment_method,
            'payment_status'        => $this->payment_status,
            'transaction_reference' => $this->transaction_reference,
            'notes'                 => $this->notes,
            'method'                => $this->payment_method,
            'status'                => $this->payment_status,
            'reference_number'      => $this->transaction_reference,
            'created_at'            => $this->created_at?->toIso8601String(),
        ];
    }
}
