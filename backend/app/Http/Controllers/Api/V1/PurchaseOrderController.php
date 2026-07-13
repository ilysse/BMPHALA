<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Models\Inventory;
use App\Models\PurchaseOrder;
use App\Models\StockMovement;
use App\Services\NotificationBroadcaster;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;

class PurchaseOrderController extends Controller
{
    public function index(Request $request)
    {
        $query = PurchaseOrder::with(['supplier', 'warehouse', 'items.product']);

        if ($request->filled('status')) {
            $query->where('status', $request->input('status'));
        }

        if ($request->filled('supplier_id')) {
            $query->where('supplier_id', $request->input('supplier_id'));
        }

        if ($request->filled('warehouse_id')) {
            $query->where('warehouse_id', $request->input('warehouse_id'));
        }

        if ($request->filled('from')) {
            $query->whereDate('order_date', '>=', $request->date('from'));
        }

        if ($request->filled('to')) {
            $query->whereDate('order_date', '<=', $request->date('to'));
        }

        if ($request->filled('search')) {
            $search = $request->input('search');
            $query->where(function ($builder) use ($search) {
                $builder->where('po_number', 'like', "%{$search}%")
                    ->orWhereHas('supplier', fn ($supplier) => $supplier->where('name', 'like', "%{$search}%"));
            });
        }

        $orders = $query->latest()->paginate($request->integer('per_page', 15));

        return response()->json([
            'success' => true,
            'message' => 'Purchase orders retrieved.',
            'data' => $orders->items(),
            'meta' => [
                'page' => $orders->currentPage(),
                'per_page' => $orders->perPage(),
                'total' => $orders->total(),
                'last_page' => $orders->lastPage(),
            ],
            'errors' => null,
        ]);
    }

    public function store(Request $request)
    {
        $data = $request->validate([
            'supplier_id' => ['required', 'exists:suppliers,id'],
            'warehouse_id' => ['required', 'exists:warehouses,id'],
            'status' => ['nullable', 'in:draft,ordered'],
            'order_date' => ['nullable', 'date'],
            'expected_at' => ['nullable', 'date'],
            'tax_amount' => ['nullable', 'numeric', 'min:0'],
            'shipping_amount' => ['nullable', 'numeric', 'min:0'],
            'notes' => ['nullable', 'string'],
            'items' => ['required', 'array', 'min:1'],
            'items.*.product_id' => ['required', 'exists:products,id'],
            'items.*.quantity_ordered' => ['required', 'integer', 'min:1'],
            'items.*.unit_cost' => ['required', 'numeric', 'min:0'],
        ]);

        $purchaseOrder = DB::transaction(function () use ($data) {
            $subtotal = collect($data['items'])->sum(
                fn ($item) => (float) $item['unit_cost'] * (int) $item['quantity_ordered']
            );
            $tax = (float) ($data['tax_amount'] ?? 0);
            $shipping = (float) ($data['shipping_amount'] ?? 0);

            $purchaseOrder = PurchaseOrder::create([
                'supplier_id' => $data['supplier_id'],
                'warehouse_id' => $data['warehouse_id'],
                'po_number' => $this->nextNumber(),
                'status' => $data['status'] ?? 'ordered',
                'order_date' => $data['order_date'] ?? now()->toDateString(),
                'expected_at' => $data['expected_at'] ?? null,
                'subtotal' => $subtotal,
                'tax_amount' => $tax,
                'shipping_amount' => $shipping,
                'total_amount' => $subtotal + $tax + $shipping,
                'notes' => $data['notes'] ?? null,
            ]);

            foreach ($data['items'] as $item) {
                $quantity = (int) $item['quantity_ordered'];
                $unitCost = (float) $item['unit_cost'];
                $purchaseOrder->items()->create([
                    'product_id' => $item['product_id'],
                    'quantity_ordered' => $quantity,
                    'quantity_received' => 0,
                    'unit_cost' => $unitCost,
                    'total_cost' => $unitCost * $quantity,
                ]);
            }

            return $purchaseOrder->load(['supplier', 'warehouse', 'items.product']);
        });

        return response()->json([
            'success' => true,
            'message' => 'Purchase order created.',
            'data' => $purchaseOrder,
            'meta' => null,
            'errors' => null,
        ], 201);
    }

    public function show(PurchaseOrder $purchaseOrder)
    {
        return response()->json([
            'success' => true,
            'message' => 'Purchase order retrieved.',
            'data' => $purchaseOrder->load(['supplier', 'warehouse', 'items.product']),
            'meta' => null,
            'errors' => null,
        ]);
    }

    public function updateStatus(Request $request, PurchaseOrder $purchaseOrder)
    {
        $data = $request->validate([
            'status' => ['required', 'in:draft,ordered,partially_received,received,cancelled'],
        ]);

        $purchaseOrder->update($data);

        return response()->json([
            'success' => true,
            'message' => 'Purchase order status updated.',
            'data' => $purchaseOrder->fresh(['supplier', 'warehouse', 'items.product']),
            'meta' => null,
            'errors' => null,
        ]);
    }

    public function receive(Request $request, PurchaseOrder $purchaseOrder)
    {
        if (in_array($purchaseOrder->status, ['received', 'cancelled'], true)) {
            return response()->json([
                'success' => false,
                'message' => 'This purchase order cannot be received.',
                'data' => null,
                'meta' => null,
                'errors' => ['status' => ['Only open purchase orders can be received.']],
            ], 422);
        }

        $data = $request->validate([
            'items' => ['nullable', 'array'],
            'items.*.item_id' => ['required_with:items', 'exists:purchase_order_items,id'],
            'items.*.quantity' => ['required_with:items', 'integer', 'min:1'],
            'notes' => ['nullable', 'string'],
        ]);

        $restocked = [];

        $purchaseOrder = DB::transaction(function () use ($purchaseOrder, $data, &$restocked) {
            $purchaseOrder->load('items.product');
            $receiveMap = collect($data['items'] ?? [])
                ->mapWithKeys(fn ($item) => [$item['item_id'] => (int) $item['quantity']]);

            foreach ($purchaseOrder->items as $item) {
                $remaining = $item->quantity_ordered - $item->quantity_received;
                if ($remaining <= 0) {
                    continue;
                }

                $quantity = $receiveMap->isEmpty()
                    ? $remaining
                    : min($remaining, (int) ($receiveMap[$item->id] ?? 0));

                if ($quantity <= 0) {
                    continue;
                }

                $inventory = Inventory::firstOrCreate(
                    [
                        'product_id' => $item->product_id,
                        'warehouse_id' => $purchaseOrder->warehouse_id,
                    ],
                    [
                        'quantity' => 0,
                        'min_stock' => 10,
                        'max_stock' => 1000,
                    ]
                );

                $previousQuantity = $inventory->quantity;
                $inventory->increment('quantity', $quantity);
                $inventory->refresh();
                $item->increment('quantity_received', $quantity);

                if ($previousQuantity <= 0 && $inventory->quantity > 0) {
                    $restocked[] = [
                        'product' => $item->product,
                        'quantity' => $quantity,
                        'stock' => $inventory->quantity,
                    ];
                }

                StockMovement::create([
                    'product_id' => $item->product_id,
                    'warehouse_id' => $purchaseOrder->warehouse_id,
                    'type' => 'in',
                    'quantity' => $quantity,
                    'reference_type' => 'purchase_order',
                    'reference_id' => $purchaseOrder->id,
                    'reason' => $data['notes'] ?? "Received {$purchaseOrder->po_number}",
                    'user_id' => auth()->id(),
                ]);
            }

            $purchaseOrder->refresh()->load('items');
            $fullyReceived = $purchaseOrder->items->every(
                fn ($item) => $item->quantity_received >= $item->quantity_ordered
            );
            $partiallyReceived = $purchaseOrder->items->contains(
                fn ($item) => $item->quantity_received > 0
            );

            $purchaseOrder->update([
                'status' => $fullyReceived ? 'received' : ($partiallyReceived ? 'partially_received' : $purchaseOrder->status),
                'received_at' => $fullyReceived ? now() : $purchaseOrder->received_at,
            ]);

            return $purchaseOrder->fresh(['supplier', 'warehouse', 'items.product']);
        });

        foreach ($restocked as $item) {
            app(NotificationBroadcaster::class)->productRestocked(
                $item['product'],
                $item['quantity'],
                $item['stock']
            );
        }

        return response()->json([
            'success' => true,
            'message' => 'Purchase order received.',
            'data' => $purchaseOrder,
            'meta' => null,
            'errors' => null,
        ]);
    }

    public function stats()
    {
        $openStatuses = ['draft', 'ordered', 'partially_received'];

        return response()->json([
            'success' => true,
            'message' => 'Procurement stats retrieved.',
            'data' => [
                'open_purchase_orders' => PurchaseOrder::whereIn('status', $openStatuses)->count(),
                'ordered_value' => PurchaseOrder::whereIn('status', $openStatuses)->sum('total_amount'),
                'received_value' => PurchaseOrder::where('status', 'received')->sum('total_amount'),
                'supplier_count' => \App\Models\Supplier::where('is_active', true)->count(),
            ],
            'meta' => null,
            'errors' => null,
        ]);
    }

    private function nextNumber(): string
    {
        return 'PO-' . now()->format('Ymd') . '-' . strtoupper(Str::random(5));
    }
}
