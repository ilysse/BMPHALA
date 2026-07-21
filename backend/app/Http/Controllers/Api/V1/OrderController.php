<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Models\Order;
use App\Models\OrderItem;
use App\Models\Product;
use App\Models\Inventory;
use App\Models\StockMovement;
use App\Services\PromotionEngine;
use App\Http\Requests\Api\V1\StoreOrderRequest;
use App\Http\Requests\Api\V1\UpdateOrderStatusRequest;
use App\Http\Resources\Api\V1\OrderResource;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;
use InvalidArgumentException;
use Carbon\Carbon;

class OrderController extends Controller
{
    protected PromotionEngine $promotionEngine;

    public function __construct(PromotionEngine $promotionEngine)
    {
        $this->promotionEngine = $promotionEngine;
    }

    public function index(Request $request)
    {
        $query = Order::with(['retailer', 'distributor', 'items']);

        // Role-based filtering
        $user = auth()->user();
        if ($user->role === 'retailer') {
            $query->where('retailer_id', $user->id);
        } elseif ($user->role === 'distributor') {
            $query->where('distributor_id', $user->id);
        } elseif ($user->role === 'sales_rep') {
            // Only see orders from retailers assigned to this sales rep
            $query->whereHas('retailer', function($q) use ($user) {
                $q->where('metadata->responsible_id', $user->id);
            });
        }

        if ($request->filled('status')) {
            $query->where('status', $request->status);
        }

        if ($request->filled('payment_status')) {
            $query->where('payment_status', $request->payment_status);
        }

        if ($request->filled('from')) {
            $query->where('created_at', '>=', \Carbon\Carbon::parse($request->from)->startOfDay());
        }
        if ($request->filled('to')) {
            $query->where('created_at', '<=', \Carbon\Carbon::parse($request->to)->endOfDay());
        }

        if ($request->filled('representative_id')) {
            $query->whereHas('retailer', function($q) use ($request) {
                $q->where('metadata->responsible_id', $request->representative_id);
            });
        }

        if ($request->filled('search')) {
            $search = $request->search;
            $query->where(function($q) use ($search) {
                $q->where('order_number', 'LIKE', "%{$search}%")
                  ->orWhereHas('retailer', function($rq) use ($search) {
                      $rq->where('name', 'LIKE', "%{$search}%");
                  });
            });
        }

        if ($request->filled('retailer_id')) {
            $query->where('retailer_id', $request->retailer_id);
        }

        if ($request->filled('brand_id') || $request->filled('category_id')) {
            $query->whereHas('items.product', function ($productQuery) use ($request) {
                if ($request->filled('brand_id')) {
                    $productQuery->where('brand_id', $request->brand_id);
                }
                if ($request->filled('category_id')) {
                    $productQuery->where('category_id', $request->category_id);
                }
            });
        }

        if ($request->filled('min_total')) {
            $query->where('grand_total', '>=', (float) $request->min_total);
        }
        if ($request->filled('max_total')) {
            $query->where('grand_total', '<=', (float) $request->max_total);
        }

        $orders = $query->orderBy('created_at', 'desc')
            ->paginate($request->integer('per_page', 15));

        return response()->json([
            'success' => true,
            'message' => 'Orders retrieved successfully.',
            'data' => OrderResource::collection($orders->items()),
            'meta' => [
                'page' => $orders->currentPage(),
                'per_page' => $orders->perPage(),
                'total' => $orders->total(),
                'last_page' => $orders->lastPage(),
            ],
            'errors' => null
        ]);
    }

    public function store(StoreOrderRequest $request)
    {
        $data = $request->validated();
        $user = auth()->user();

        return DB::transaction(function () use ($data, $user) {
            // 1. Calculate pricing via PromotionEngine
            $calcResult = $this->promotionEngine->calculate($data['items']);

            // Orders after 18:00 local time are scheduled two calendar days ahead.
            $localNow = Carbon::now(env('ORDER_CUTOFF_TIMEZONE', 'Africa/Casablanca'));
            $deliveryDays = $localNow->hour >= 18 ? 2 : 1;
            $expectedDeliveryAt = $localNow->copy()
                ->addDays($deliveryDays)
                ->startOfDay()
                ->setHour(9)
                ->utc();

            // 2. Create Order
            $order = Order::create([
                'id' => (string) Str::ulid(),
                'order_number' => 'ORD-' . strtoupper(Str::random(8)),
                'retailer_id' => $user->id,
                'status' => 'pending',
                'payment_status' => 'unpaid',
                'total_amount' => $calcResult['total_amount'],
                'discount_amount' => $calcResult['total_discount'],
                'tax_amount' => 0.00,
                'shipping_amount' => 0.00,
                'grand_total' => $calcResult['grand_total'],
                'delivery_address' => $data['delivery_address'] ?? ($user->address ?: ($user->metadata['address_string'] ?? '')),
                'delivery_latitude' => $data['delivery_latitude'] ?? $user->latitude,
                'delivery_longitude' => $data['delivery_longitude'] ?? $user->longitude,
                'delivery_gps' => (
                    ($data['delivery_latitude'] ?? $user->latitude) !== null
                    && ($data['delivery_longitude'] ?? $user->longitude) !== null
                ) ? ($data['delivery_latitude'] ?? $user->latitude) . ',' . ($data['delivery_longitude'] ?? $user->longitude) : null,
                'notes' => $data['notes'] ?? null,
                'expected_delivery_at' => $expectedDeliveryAt,
            ]);

            // 3. Create Order Items & Reserve Stock
            foreach ($calcResult['items'] as $itemData) {
                $product = Product::find($itemData['product_id']);
                
                OrderItem::create([
                    'id' => (string) Str::ulid(),
                    'order_id' => $order->id,
                    'product_id' => $itemData['product_id'],
                    'product_name' => $itemData['name'],
                    'quantity' => $itemData['quantity'],
                    'unit_price' => $itemData['unit_price'],
                    'discount_amount' => $itemData['discount_amount'],
                    'total_price' => $itemData['total_price'],
                ]);

                // Reserve stock in inventory (using default/first warehouse)
                $inventory = Inventory::where('product_id', $product->id)->first();
                if ($inventory) {
                    if ($inventory->quantity < $itemData['quantity']) {
                        throw new \Exception("Insufficient stock for product: {$product->name}");
                    }
                    $inventory->quantity -= $itemData['quantity'];
                    $inventory->save();

                    StockMovement::create([
                        'id' => (string) Str::ulid(),
                        'company_id' => $order->company_id,
                        'product_id' => $product->id,
                        'warehouse_id' => $inventory->warehouse_id,
                        'type' => 'reservation',
                        'quantity' => $itemData['quantity'],
                        'reference_id' => $order->id,
                        'reference_type' => 'order',
                        'user_id' => $user->id,
                        'reason' => "Stock reserved for order {$order->order_number}",
                    ]);
                }
            }

            // Log initial history
            $order->history()->create([
                'id' => (string) Str::ulid(),
                'company_id' => $order->company_id,
                'status' => 'pending',
                'changed_by' => $user->id,
                'notes' => "Order created. Scheduled delivery: {$expectedDeliveryAt->toIso8601String()}.",
            ]);

            return response()->json([
                'success' => true,
                'message' => 'Order placed successfully.',
                'data' => new OrderResource($order->load('items')),
                'meta' => null,
                'errors' => null
            ], 201);
        });
    }

    public function show(Order $order)
    {
        return response()->json([
            'success' => true,
            'message' => 'Order details retrieved.',
            'data' => new OrderResource($order->load(['items', 'retailer', 'distributor', 'history'])),
            'meta' => null,
            'errors' => null
        ]);
    }

    public function updateStatus(UpdateOrderStatusRequest $request, Order $order)
    {
        $data = $request->validated();
        try {
            $order->transitionTo($data['status'], $data['reason'] ?? null, auth()->user());
        } catch (InvalidArgumentException $e) {
            return response()->json([
                'success' => false,
                'message' => $e->getMessage(),
                'data' => null,
                'meta' => null,
                'errors' => ['status' => [$e->getMessage()]],
            ], 422);
        }

        return response()->json([
            'success' => true,
            'message' => "Order status updated to {$data['status']}.",
            'data' => new OrderResource($order->load('items')),
            'meta' => null,
            'errors' => null
        ]);
    }

    public function assign(Request $request, Order $order)
    {
        $request->validate([
            'distributor_id' => 'required|exists:users,id'
        ]);

        $order->distributor_id = $request->distributor_id;
        $order->status = 'assigned';
        $order->save();

        $order->history()->create([
            'id' => (string) Str::ulid(),
            'company_id' => $order->company_id,
            'status' => 'assigned',
            'changed_by' => auth()->id(),
            'notes' => 'Distributor assigned.',
        ]);

        return response()->json([
            'success' => true,
            'message' => 'Distributor assigned successfully.',
            'data' => new OrderResource($order->load('distributor')),
            'meta' => null,
            'errors' => null
        ]);
    }

    public function deliver(Request $request, Order $order)
    {
        $request->validate([
            'signature_url' => 'nullable|string',
            'photo_url' => 'nullable|string',
            'notes' => 'nullable|string',
        ]);

        return DB::transaction(function () use ($request, $order) {
            $order->status = 'delivered';
            $order->actual_delivery_at = now();
            $order->delivery_signature_url = $request->signature_url;
            $order->delivery_photo_url = $request->photo_url;
            if ($request->filled('notes')) {
                $order->notes = ($order->notes ? $order->notes . "\n" : '') . $request->notes;
            }
            $order->save();

            // Release reserved stock permanently
            foreach ($order->items as $item) {
                $inventory = Inventory::where('product_id', $item->product_id)->first();
                if ($inventory) {

                    StockMovement::create([
                        'id' => (string) Str::ulid(),
                        'company_id' => $order->company_id,
                        'product_id' => $item->product_id,
                        'warehouse_id' => $inventory->warehouse_id,
                        'type' => 'release',
                        'quantity' => $item->quantity,
                        'reference_id' => $order->id,
                        'reference_type' => 'order',
                        'user_id' => auth()->id(),
                        'reason' => "Stock released on delivery for order {$order->order_number}",
                    ]);
                }
            }

            $order->history()->create([
                'id' => (string) Str::ulid(),
                'company_id' => $order->company_id,
                'status' => 'delivered',
                'changed_by' => auth()->id(),
                'notes' => 'Order marked as delivered.',
            ]);

            return response()->json([
                'success' => true,
                'message' => 'Order delivered successfully.',
                'data' => new OrderResource($order),
                'meta' => null,
                'errors' => null
            ]);
        });
    }

    public function cancel(Request $request, Order $order)
    {
        $request->validate([
            'reason' => 'nullable|string',
        ]);

        return DB::transaction(function () use ($request, $order) {
            if (in_array($order->status, ['delivered', 'cancelled', 'returned'])) {
                return response()->json([
                    'success' => false,
                    'message' => 'Cannot cancel an order that is already ' . $order->status,
                    'data' => null,
                    'meta' => null,
                    'errors' => null
                ], 422);
            }

            $order->status = 'cancelled';
            $order->save();

            // Restore stock reserved during order placement.
            foreach ($order->items as $item) {
                $inventory = Inventory::where('product_id', $item->product_id)->first();
                if ($inventory) {
                    $inventory->quantity += $item->quantity;
                    $inventory->save();

                    StockMovement::create([
                        'id' => (string) Str::ulid(),
                        'company_id' => $order->company_id,
                        'product_id' => $item->product_id,
                        'warehouse_id' => $inventory->warehouse_id,
                        'type' => 'release',
                        'quantity' => $item->quantity,
                        'reference_id' => $order->id,
                        'reference_type' => 'order',
                        'user_id' => auth()->id(),
                        'reason' => "Stock restored (order cancelled) for order {$order->order_number}",
                    ]);
                }
            }

            $order->history()->create([
                'id' => (string) Str::ulid(),
                'company_id' => $order->company_id,
                'status' => 'cancelled',
                'changed_by' => auth()->id(),
                'notes' => $request->reason ?: 'Order cancelled.',
            ]);

            return response()->json([
                'success' => true,
                'message' => 'Order cancelled successfully.',
                'data' => new OrderResource($order),
                'meta' => null,
                'errors' => null
            ]);
        });
    }
}
