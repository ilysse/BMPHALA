<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Models\Inventory;
use App\Models\StockMovement;
use App\Services\NotificationBroadcaster;
use Illuminate\Http\Request;
use Illuminate\Support\Str;

class InventoryController extends Controller
{
    public function index(Request $request)
    {
        $query = Inventory::with(['product', 'warehouse']);

        if ($request->filled('warehouse_id')) {
            $query->where('warehouse_id', $request->warehouse_id);
        }

        if ($request->filled('product_id')) {
            $query->where('product_id', $request->product_id);
        }

        $inventory = $query->paginate($request->integer('per_page', 15));

        return response()->json([
            'success' => true,
            'message' => 'Inventory retrieved.',
            'data' => $inventory->items(),
            'meta' => [
                'page' => $inventory->currentPage(),
                'per_page' => $inventory->perPage(),
                'total' => $inventory->total(),
                'last_page' => $inventory->lastPage(),
            ],
            'errors' => null
        ]);
    }

    public function adjust(Request $request)
    {
        $data = $request->validate([
            'product_id' => 'required|exists:products,id',
            'warehouse_id' => 'required|exists:warehouses,id',
            'quantity' => 'required|integer', // Can be positive (in) or negative (out)
            'notes' => 'nullable|string',
        ]);

        $inventory = Inventory::firstOrCreate(
            [
                'product_id' => $data['product_id'],
                'warehouse_id' => $data['warehouse_id'],
            ],
            [
                'id' => (string) Str::ulid(),
                'quantity' => 0,
                'min_stock' => 10,
                'max_stock' => 1000,
            ]
        );

        $type = $data['quantity'] >= 0 ? 'in' : 'out';
        $quantityChange = abs($data['quantity']);
        $previousQuantity = $inventory->quantity;

        if ($type === 'out' && $inventory->quantity < $quantityChange) {
            return response()->json([
                'success' => false,
                'message' => 'Cannot adjust stock below 0.',
                'data' => null,
                'meta' => null,
                'errors' => ['quantity' => ['Insufficient stock to complete this reduction.']]
            ], 422);
        }

        if ($type === 'in') {
            $inventory->quantity += $quantityChange;
        } else {
            $inventory->quantity -= $quantityChange;
        }
        $inventory->save();

        StockMovement::create([
            'id' => (string) Str::ulid(),
            'company_id' => $inventory->company_id,
            'product_id' => $data['product_id'],
            'warehouse_id' => $data['warehouse_id'],
            'type' => 'adjustment',
            'quantity' => $data['quantity'],
            'reference_id' => null,
            'reference_type' => 'manual',
            'user_id' => auth()->id(),
            'reason' => $data['notes'] ?? 'Manual stock adjustment.',
        ]);

        if ($data['quantity'] > 0 && $previousQuantity <= 0 && $inventory->quantity > 0) {
            app(NotificationBroadcaster::class)->productRestocked(
                $inventory->product()->firstOrFail(),
                $quantityChange,
                $inventory->quantity
            );
        }

        return response()->json([
            'success' => true,
            'message' => 'Inventory adjusted successfully.',
            'data' => $inventory,
            'meta' => null,
            'errors' => null
        ]);
    }
}
