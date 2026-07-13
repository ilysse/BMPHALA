<?php

namespace App\Http\Resources\Api\V1;

use App\Models\Order;
use App\Models\User;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

class UserResource extends JsonResource
{
    /**
     * Transform the resource into an array.
     *
     * @return array<string, mixed>
     */
    public function toArray(Request $request): array
    {
        $metadata = $this->metadata ?? [];
        $repStats = $this->role === 'sales_rep' ? $this->representativeStats() : [];

        return [
            'id'         => $this->id,
            'name'       => $this->name,
            'email'      => $this->email,
            'role'       => $this->role,
            'company_id' => $this->company_id,
            'status'     => $this->status,
            'phone'      => $metadata['phone'] ?? null,
            'latitude'   => $this->latitude,
            'longitude'  => $this->longitude,
            'address'    => $this->address,
            'can_collect_cash' => (bool) ($metadata['can_collect_cash'] ?? false),
            'representative_features' => $this->representativeFeatures($metadata),
            'referral_code' => $metadata['referral_code'] ?? null,
            'referred_by' => $metadata['responsible_id'] ?? null,
            'sales_performance' => $repStats['sales_performance'] ?? null,
            'sales_order_count' => $repStats['sales_order_count'] ?? null,
            'assigned_retailer_count' => $repStats['assigned_retailer_count'] ?? null,
            'created_at' => $this->created_at?->toIso8601String(),
        ];
    }

    private function representativeFeatures(array $metadata): array
    {
        $features = $metadata['representative_features'] ?? [];

        return [
            'dashboard' => (bool) ($features['dashboard'] ?? true),
            'retailers' => (bool) ($features['retailers'] ?? true),
            'orders' => (bool) ($features['orders'] ?? true),
            'onboarding' => (bool) ($features['onboarding'] ?? true),
        ];
    }

    private function representativeStats(): array
    {
        $retailerIds = User::withoutGlobalScopes()
            ->where('company_id', $this->company_id)
            ->where('role', 'retailer')
            ->where('metadata->responsible_id', $this->id)
            ->pluck('id');

        $orders = Order::withoutGlobalScopes()
            ->where('company_id', $this->company_id)
            ->whereIn('retailer_id', $retailerIds)
            ->where('status', '!=', 'cancelled');

        return [
            'sales_performance' => round((float) $orders->sum('grand_total'), 2),
            'sales_order_count' => (clone $orders)->count(),
            'assigned_retailer_count' => $retailerIds->count(),
        ];
    }
}
