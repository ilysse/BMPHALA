<?php

namespace App\Services;

use App\Jobs\SendPushNotification;
use App\Models\Notification;
use App\Models\Product;
use App\Models\PromotionRule;
use App\Models\User;

class NotificationBroadcaster
{
    public function productCreated(Product $product): void
    {
        $this->broadcast(
            'product_new',
            'New product available',
            "{$product->name} has been added to the catalog.",
            [
                'product_id' => $product->id,
                'product_name' => $product->name,
                'sku' => $product->sku,
            ]
        );
    }

    public function productRestocked(Product $product, int $quantityAdded, int $currentStock): void
    {
        $this->broadcast(
            'product_restocked',
            'Product restocked',
            "{$product->name} is back in stock. {$quantityAdded} units added, {$currentStock} now available.",
            [
                'product_id' => $product->id,
                'product_name' => $product->name,
                'quantity_added' => $quantityAdded,
                'current_stock' => $currentStock,
            ]
        );
    }

    public function promotionActivated(PromotionRule $promotion, string $action = 'created'): void
    {
        $title = match ($action) {
            'activated' => 'Promotion activated',
            'updated' => 'Promotion updated',
            default => 'New promotion',
        };

        $this->broadcast(
            'promotion',
            $title,
            "{$promotion->name} is now available.",
            [
                'promotion_id' => $promotion->id,
                'promotion_name' => $promotion->name,
                'promotion_type' => $promotion->type,
                'configuration' => $promotion->configuration,
            ]
        );
    }

    private function broadcast(string $type, string $title, string $body, array $data = []): void
    {
        User::query()
            ->where('status', 'active')
            ->whereIn('role', ['admin', 'retailer', 'sales_rep', 'distributor'])
            ->select(['id', 'company_id'])
            ->chunkById(100, function ($users) use ($type, $title, $body, $data) {
                foreach ($users as $user) {
                    Notification::create([
                        'company_id' => $user->company_id,
                        'user_id' => $user->id,
                        'type' => $type,
                        'title' => $title,
                        'body' => $body,
                        'data' => $data,
                    ]);
                    SendPushNotification::dispatch(
                        $user->id,
                        $title,
                        $body,
                        array_merge($data, ['type' => $type]),
                    );
                }
            });
    }
}
