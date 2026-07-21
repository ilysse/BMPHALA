<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Models\Product;
use App\Http\Requests\Api\V1\StoreProductRequest;
use App\Http\Requests\Api\V1\UpdateProductRequest;
use App\Http\Resources\Api\V1\ProductResource;
use App\Services\NotificationBroadcaster;
use Illuminate\Http\Request;

class ProductController extends Controller
{
    public function index(Request $request)
    {
        $query = Product::with(['category', 'brand'])
            ->withSum('inventory as stock', 'quantity');

        if ($request->filled('category_id')) {
            $query->where('category_id', $request->category_id);
        }

        if ($request->filled('brand_id')) {
            $query->where('brand_id', $request->brand_id);
        }

        if ($request->filled('search')) {
            $search = $request->search;
            $query->where(function($q) use ($search) {
                $q->where('name', 'like', "%{$search}%")
                  ->orWhere('sku', 'like', "%{$search}%")
                  ->orWhere('barcode', 'like', "%{$search}%");
            });
        }

        if ($request->filled('status')) {
            $query->where('is_active', $request->status === 'active');
        }

        $products = $query->paginate($request->integer('per_page', 15));

        return response()->json([
            'success' => true,
            'message' => 'Products retrieved successfully.',
            'data' => ProductResource::collection($products->items()),
            'meta' => [
                'page' => $products->currentPage(),
                'per_page' => $products->perPage(),
                'total' => $products->total(),
                'last_page' => $products->lastPage(),
            ],
            'errors' => null
        ]);
    }

    public function store(StoreProductRequest $request)
    {
        $product = Product::create($request->validated());
        $product->loadSum('inventory as stock', 'quantity');

        app(NotificationBroadcaster::class)->productCreated($product);

        return response()->json([
            'success' => true,
            'message' => 'Product created successfully.',
            'data' => new ProductResource($product->load(['category', 'brand'])),
            'meta' => null,
            'errors' => null
        ], 201);
    }

    public function show(string $product)
    {
        $product = Product::withSum('inventory as stock', 'quantity')->findOrFail($product);

        return response()->json([
            'success' => true,
            'message' => 'Product details retrieved.',
            'data' => new ProductResource($product->load(['category', 'brand'])),
            'meta' => null,
            'errors' => null
        ]);
    }

    public function update(UpdateProductRequest $request, string $product)
    {
        $product = Product::findOrFail($product);
        $product->update($request->validated());
        $product->loadSum('inventory as stock', 'quantity');

        return response()->json([
            'success' => true,
            'message' => 'Product updated successfully.',
            'data' => new ProductResource($product->load(['category', 'brand'])),
            'meta' => null,
            'errors' => null
        ]);
    }

    public function destroy(string $product)
    {
        $product = Product::findOrFail($product);
        $product->delete();

        return response()->json([
            'success' => true,
            'message' => 'Product deleted successfully.',
            'data' => null,
            'meta' => null,
            'errors' => null
        ]);
    }
}
