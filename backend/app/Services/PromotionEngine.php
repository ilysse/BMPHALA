<?php

namespace App\Services;

use App\Models\PromotionRule;
use App\Models\Product;

class PromotionEngine
{
    /**
     * Calculate discount for a given set of items.
     *
     * @param array $items Array of items, each with 'product_id' and 'quantity'.
     * @return array
     */
    public function calculate(array $items): array
    {
        // 1. Fetch products
        $productIds = collect($items)->pluck('product_id')->unique()->toArray();
        $products = Product::whereIn('id', $productIds)->get()->keyBy('id');

        // 2. Fetch active promotion rules, ordered by priority
        $rules = PromotionRule::where('is_active', true)
            ->where(function ($query) {
                $query->whereNull('start_date')->orWhere('start_date', '<=', now());
            })
            ->where(function ($query) {
                $query->whereNull('end_date')->orWhere('end_date', '>=', now());
            })
            ->orderBy('priority', 'desc')
            ->get();

        $processedItems = [];
        $totalAmount = 0.00;
        $totalDiscount = 0.00;

        // Map items with product data and initial pricing
        foreach ($items as $item) {
            $productId = $item['product_id'];
            $qty = $item['quantity'];
            $product = $products->get($productId);

            if (!$product) {
                continue;
            }

            $unitPrice = (float) $product->price;
            $subtotal = $unitPrice * $qty;

            $processedItems[$productId] = [
                'product_id' => $productId,
                'name' => $product->name,
                'quantity' => $qty,
                'unit_price' => $unitPrice,
                'discount_amount' => 0.00,
                'total_price' => $subtotal,
            ];

            $totalAmount += $subtotal;
        }

        // Apply rules
        foreach ($rules as $rule) {
            $config = $rule->configuration;
            $type = $rule->type;
            $targetProductIds = $this->targetProductIds($config);

            if ($type === 'percentage') {
                $percentage = (float) ($config['percentage'] ?? 0);

                foreach ($processedItems as $productId => &$pItem) {
                    if (empty($targetProductIds) || in_array($productId, $targetProductIds)) {
                        $itemDiscount = ($pItem['unit_price'] * $pItem['quantity']) * ($percentage / 100);
                        $remainingPrice = $pItem['total_price'] - $pItem['discount_amount'];
                        $appliedDiscount = min($itemDiscount, $remainingPrice);

                        $pItem['discount_amount'] += $appliedDiscount;
                        $pItem['total_price'] -= $appliedDiscount;
                        $totalDiscount += $appliedDiscount;
                    }
                }
            } elseif ($type === 'fixed') {
                $fixedDiscount = (float) ($config['discount_amount'] ?? $config['amount'] ?? 0);

                foreach ($processedItems as $productId => &$pItem) {
                    if (empty($targetProductIds) || in_array($productId, $targetProductIds)) {
                        $remainingPrice = $pItem['total_price'] - $pItem['discount_amount'];
                        $appliedDiscount = min($fixedDiscount, $remainingPrice);

                        $pItem['discount_amount'] += $appliedDiscount;
                        $pItem['total_price'] -= $appliedDiscount;
                        $totalDiscount += $appliedDiscount;
                    }
                }
            } elseif ($type === 'bulk_tier') {
                $tiers = $config['tiers'] ?? [];
                $bulkProductIds = $targetProductIds;

                foreach ($bulkProductIds as $targetProductId) {
                if ($targetProductId && isset($processedItems[$targetProductId]) && !empty($tiers)) {
                    $pItem = &$processedItems[$targetProductId];
                    $qty = $pItem['quantity'];

                    usort($tiers, function ($a, $b) {
                        return $b['min_quantity'] <=> $a['min_quantity'];
                    });

                    $matchedTier = null;
                    foreach ($tiers as $tier) {
                        if ($qty >= $tier['min_quantity']) {
                            $matchedTier = $tier;
                            break;
                        }
                    }

                    if ($matchedTier) {
                        $tierUnitPrice = array_key_exists('unit_price', $matchedTier)
                            ? (float) $matchedTier['unit_price']
                            : max(0.00, $pItem['unit_price'] - (float) ($matchedTier['discount'] ?? 0));
                        $normalTotalPrice = $pItem['unit_price'] * $qty;
                        $tierTotalPrice = $tierUnitPrice * $qty;
                        $tierDiscount = max(0.00, $normalTotalPrice - $tierTotalPrice);

                        $remainingPrice = $pItem['total_price'] - $pItem['discount_amount'];
                        $appliedDiscount = min($tierDiscount, $remainingPrice);

                        $pItem['discount_amount'] += $appliedDiscount;
                        $pItem['total_price'] -= $appliedDiscount;
                        $totalDiscount += $appliedDiscount;
                    }
                }
                }
            } elseif ($type === 'buy_x_get_y') {
                // Config: ['buy_product_id' => '...', 'buy_qty' => 3, 'get_product_id' => '...', 'get_qty' => 1, 'discount_percentage' => 100]
                $buyProductId = $config['buy_product_id'] ?? null;
                $buyQty = (int) ($config['buy_qty'] ?? 1);
                $getProductId = $config['get_product_id'] ?? null;
                $getQty = (int) ($config['get_qty'] ?? 1);
                $discountPercent = (float) ($config['discount_percentage'] ?? 100);

                if ($buyProductId && $getProductId && isset($processedItems[$buyProductId]) && isset($processedItems[$getProductId])) {
                    $buyItem = $processedItems[$buyProductId];
                    $getItem = &$processedItems[$getProductId];

                    $timesApplicable = floor($buyItem['quantity'] / $buyQty);
                    if ($timesApplicable > 0) {
                        $allowedDiscountQty = $timesApplicable * $getQty;
                        $actualDiscountQty = min($getItem['quantity'], $allowedDiscountQty);

                        $discountPerUnit = $getItem['unit_price'] * ($discountPercent / 100);
                        $dealDiscount = $discountPerUnit * $actualDiscountQty;

                        $remainingPrice = $getItem['total_price'] - $getItem['discount_amount'];
                        $appliedDiscount = min($dealDiscount, $remainingPrice);

                        $getItem['discount_amount'] += $appliedDiscount;
                        $getItem['total_price'] -= $appliedDiscount;
                        $totalDiscount += $appliedDiscount;
                    }
                }
            }
        }

        return [
            'items' => array_values($processedItems),
            'total_amount' => round($totalAmount, 2),
            'total_discount' => round($totalDiscount, 2),
            'grand_total' => round(max(0.00, $totalAmount - $totalDiscount), 2),
        ];
    }

    private function targetProductIds(array $config): array
    {
        $ids = collect($config['product_ids'] ?? [])
            ->filter()
            ->values();

        if (!empty($config['product_id'])) {
            $ids->push($config['product_id']);
        }

        if (!empty($config['brand_ids'])) {
            $ids = $ids->merge(
                Product::whereIn('brand_id', $config['brand_ids'])->pluck('id')
            );
        }

        if (!empty($config['category_ids'])) {
            $ids = $ids->merge(
                Product::whereIn('category_id', $config['category_ids'])->pluck('id')
            );
        }

        return $ids->unique()->values()->all();
    }
}
