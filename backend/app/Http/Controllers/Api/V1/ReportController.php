<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Http\Resources\Api\V1\OrderResource;
use App\Models\Order;
use App\Models\OrderItem;
use App\Models\Payment;
use App\Models\User;
use Carbon\Carbon;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class ReportController extends Controller
{
    public function sales(Request $request): JsonResponse
    {
        $data = $request->validate([
            'from' => ['nullable', 'date'],
            'to' => ['nullable', 'date'],
        ]);

        $from = isset($data['from']) ? Carbon::parse($data['from'])->startOfDay() : null;
        $to = isset($data['to']) ? Carbon::parse($data['to'])->endOfDay() : null;

        $ordersQuery = $this->scopedOrdersQuery($request)
            ->with(['retailer', 'distributor'])
            ->withSum(['payments as paid_amount' => function ($query) {
                $query->where('payment_status', 'completed');
            }], 'amount');

        if ($from) {
            $ordersQuery->where('created_at', '>=', $from);
        }

        if ($to) {
            $ordersQuery->where('created_at', '<=', $to);
        }

        if ($request->filled('status')) {
            $ordersQuery->where('status', $request->input('status'));
        }

        if ($request->filled('payment_status')) {
            $ordersQuery->where('payment_status', $request->input('payment_status'));
        }

        if ($request->filled('retailer_id')) {
            $ordersQuery->where('retailer_id', $request->input('retailer_id'));
        }

        if ($request->filled('distributor_id')) {
            $ordersQuery->where('distributor_id', $request->input('distributor_id'));
        }

        if ($request->filled('min_total')) {
            $ordersQuery->where('grand_total', '>=', (float) $request->input('min_total'));
        }

        if ($request->filled('max_total')) {
            $ordersQuery->where('grand_total', '<=', (float) $request->input('max_total'));
        }

        if ($request->filled('brand_id') || $request->filled('category_id')) {
            $ordersQuery->whereHas('items.product', function ($productQuery) use ($request) {
                if ($request->filled('brand_id')) {
                    $productQuery->where('brand_id', $request->input('brand_id'));
                }

                if ($request->filled('category_id')) {
                    $productQuery->where('category_id', $request->input('category_id'));
                }
            });
        }

        if ($request->filled('representative_id')) {
            $ordersQuery->whereHas('retailer', function($q) use ($request) {
                $q->where('metadata->responsible_id', $request->input('representative_id'));
            });
        }

        $orders = $ordersQuery->orderBy('created_at', 'desc')->get();
        $salesOrders = $orders->whereNotIn('status', ['cancelled', 'returned']);

        $completedPayments = $this->scopedPaymentsQuery($request)
            ->where('payment_status', 'completed');

        if ($from) {
            $completedPayments->where('created_at', '>=', $from);
        }

        if ($to) {
            $completedPayments->where('created_at', '<=', $to);
        }

        $totalPaid = (float) $completedPayments->sum('amount');
        $grossSales = (float) $salesOrders->sum(fn (Order $order) => (float) $order->grand_total);
        $deliveredSales = (float) $salesOrders
            ->where('status', 'delivered')
            ->sum(fn (Order $order) => (float) $order->grand_total);
        $outstanding = (float) $salesOrders->sum(function (Order $order) {
            return max(0, (float) $order->grand_total - (float) ($order->paid_amount ?? 0));
        });

        $recentOrders = $orders->take(25);
        $recentOrders->loadMissing('items');

        return response()->json([
            'success' => true,
            'message' => 'Sales report retrieved.',
            'data' => [
                'date_range' => [
                    'from' => $from?->toDateString(),
                    'to' => $to?->toDateString(),
                ],
                'gross_sales' => round($grossSales, 2),
                'delivered_sales' => round($deliveredSales, 2),
                'total_paid' => round($totalPaid, 2),
                'outstanding_balance' => round($outstanding, 2),
                'total_orders' => $orders->count(),
                'open_orders' => $orders
                    ->whereNotIn('status', ['delivered', 'cancelled', 'returned'])
                    ->count(),
                'delivered_orders' => $orders->where('status', 'delivered')->count(),
                'cancelled_orders' => $orders->whereIn('status', ['cancelled', 'returned'])->count(),
                'active_retailers_count' => $this->scopedUsersQuery($request)
                    ->where('role', 'retailer')
                    ->where('status', 'active')
                    ->count(),
                'ordering_retailers_count' => $salesOrders->pluck('retailer_id')->unique()->count(),
                'status_breakdown' => $this->breakdownBy($orders, 'status'),
                'payment_breakdown' => $this->breakdownBy($orders, 'payment_status'),
                'daily_sales' => $this->dailySales($salesOrders),
                'retailer_summary' => $this->retailerSummary($salesOrders),
                'product_summary' => $this->productSummary($request, $from, $to),
                'recent_orders' => OrderResource::collection($recentOrders)->resolve(),
            ],
            'meta' => null,
            'errors' => null,
        ]);
    }

    private function scopedOrdersQuery(Request $request)
    {
        $query = Order::query();
        $user = $request->user();

        if ($user->role === 'retailer') {
            $query->where('retailer_id', $user->id);
        } elseif ($user->role === 'distributor') {
            $query->where('distributor_id', $user->id);
        } elseif ($user->role === 'sales_rep') {
            $query->whereHas('retailer', function ($retailerQuery) use ($user) {
                $retailerQuery->where('metadata->responsible_id', $user->id);
            });
        }

        return $query;
    }

    private function scopedPaymentsQuery(Request $request)
    {
        $query = Payment::query();
        $user = $request->user();

        if ($user->role === 'retailer') {
            $orderIds = Order::where('retailer_id', $user->id)->pluck('id');
            $query->whereIn('order_id', $orderIds);
        } elseif ($user->role === 'distributor') {
            $orderIds = Order::where('distributor_id', $user->id)->pluck('id');
            $query->whereIn('order_id', $orderIds);
        } elseif ($user->role === 'sales_rep') {
            $orderIds = Order::whereHas('retailer', function ($retailerQuery) use ($user) {
                $retailerQuery->where('metadata->responsible_id', $user->id);
            })->pluck('id');
            $query->whereIn('order_id', $orderIds);
        }

        return $query;
    }

    private function scopedUsersQuery(Request $request)
    {
        $query = User::query();
        $user = $request->user();

        if ($user->role === 'sales_rep') {
            $query->where('metadata->responsible_id', $user->id);
        } elseif ($user->role === 'retailer') {
            $query->where('id', $user->id);
        }

        return $query;
    }

    private function breakdownBy($orders, string $key): array
    {
        return $orders
            ->groupBy($key)
            ->map(function ($group, $value) {
                return [
                    'label' => $value ?: 'unknown',
                    'count' => $group->count(),
                    'sales' => round((float) $group
                        ->whereNotIn('status', ['cancelled', 'returned'])
                        ->sum(fn (Order $order) => (float) $order->grand_total), 2),
                ];
            })
            ->values()
            ->all();
    }

    private function dailySales($orders): array
    {
        return $orders
            ->groupBy(fn (Order $order) => $order->created_at?->format('Y-m-d') ?? 'unknown')
            ->sortKeys()
            ->map(function ($group, $date) {
                return [
                    'date' => $date,
                    'orders' => $group->count(),
                    'sales' => round((float) $group->sum(fn (Order $order) => (float) $order->grand_total), 2),
                ];
            })
            ->values()
            ->all();
    }

    private function retailerSummary($orders): array
    {
        return $orders
            ->groupBy('retailer_id')
            ->map(function ($group) {
                $first = $group->first();

                return [
                    'retailer_id' => $first->retailer_id,
                    'retailer_name' => $first->retailer?->name ?? 'Unknown Retailer',
                    'orders' => $group->count(),
                    'sales' => round((float) $group->sum(fn (Order $order) => (float) $order->grand_total), 2),
                    'outstanding' => round((float) $group->sum(function (Order $order) {
                        return max(0, (float) $order->grand_total - (float) ($order->paid_amount ?? 0));
                    }), 2),
                ];
            })
            ->sortByDesc('sales')
            ->take(25)
            ->values()
            ->all();
    }

    private function productSummary(Request $request, ?Carbon $from, ?Carbon $to): array
    {
        $query = OrderItem::query()
            ->whereHas('order', function ($orderQuery) use ($request, $from, $to) {
                $user = $request->user();
                $orderQuery->whereNotIn('status', ['cancelled', 'returned']);

                if ($from) {
                    $orderQuery->where('created_at', '>=', $from);
                }

                if ($to) {
                    $orderQuery->where('created_at', '<=', $to);
                }

                if ($user->role === 'retailer') {
                    $orderQuery->where('retailer_id', $user->id);
                } elseif ($user->role === 'distributor') {
                    $orderQuery->where('distributor_id', $user->id);
                } elseif ($user->role === 'sales_rep') {
                    $orderQuery->whereHas('retailer', function ($retailerQuery) use ($user) {
                        $retailerQuery->where('metadata->responsible_id', $user->id);
                    });
                }
            })
            ->selectRaw('product_id, COALESCE(product_name, product_id) as product_name, SUM(quantity) as units_sold, SUM(total_price) as sales')
            ->groupBy('product_id', 'product_name')
            ->orderByDesc('sales')
            ->limit(25)
            ->get();

        return $query
            ->map(fn ($row) => [
                'product_id' => $row->product_id,
                'product_name' => $row->product_name,
                'units_sold' => (int) $row->units_sold,
                'sales' => round((float) $row->sales, 2),
            ])
            ->all();
    }
}
