<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Models\Supplier;
use Illuminate\Http\Request;

class SupplierController extends Controller
{
    public function index(Request $request)
    {
        $query = Supplier::query();

        if ($request->filled('active')) {
            $query->where('is_active', $request->boolean('active'));
        }

        if ($request->filled('search')) {
            $search = $request->input('search');
            $query->where(function ($builder) use ($search) {
                $builder->where('name', 'like', "%{$search}%")
                    ->orWhere('phone', 'like', "%{$search}%")
                    ->orWhere('email', 'like', "%{$search}%")
                    ->orWhere('tax_number', 'like', "%{$search}%");
            });
        }

        $suppliers = $query->orderBy('name')->paginate($request->integer('per_page', 15));

        return response()->json([
            'success' => true,
            'message' => 'Suppliers retrieved.',
            'data' => $suppliers->items(),
            'meta' => [
                'page' => $suppliers->currentPage(),
                'per_page' => $suppliers->perPage(),
                'total' => $suppliers->total(),
                'last_page' => $suppliers->lastPage(),
            ],
            'errors' => null,
        ]);
    }

    public function store(Request $request)
    {
        $supplier = Supplier::create($this->validatedData($request));

        return response()->json([
            'success' => true,
            'message' => 'Supplier created.',
            'data' => $supplier,
            'meta' => null,
            'errors' => null,
        ], 201);
    }

    public function show(Supplier $supplier)
    {
        return response()->json([
            'success' => true,
            'message' => 'Supplier retrieved.',
            'data' => $supplier->load('purchaseOrders'),
            'meta' => null,
            'errors' => null,
        ]);
    }

    public function update(Request $request, Supplier $supplier)
    {
        $supplier->update($this->validatedData($request, true));

        return response()->json([
            'success' => true,
            'message' => 'Supplier updated.',
            'data' => $supplier->fresh(),
            'meta' => null,
            'errors' => null,
        ]);
    }

    public function destroy(Supplier $supplier)
    {
        $supplier->update(['is_active' => false]);

        return response()->json([
            'success' => true,
            'message' => 'Supplier deactivated.',
            'data' => null,
            'meta' => null,
            'errors' => null,
        ]);
    }

    private function validatedData(Request $request, bool $partial = false): array
    {
        $required = $partial ? 'sometimes' : 'required';

        return $request->validate([
            'name' => [$required, 'string', 'max:255'],
            'contact_person' => ['nullable', 'string', 'max:255'],
            'phone' => ['nullable', 'string', 'max:50'],
            'email' => ['nullable', 'email', 'max:255'],
            'address' => ['nullable', 'string', 'max:500'],
            'tax_number' => ['nullable', 'string', 'max:100'],
            'payment_terms_days' => ['nullable', 'integer', 'min:0', 'max:365'],
            'is_active' => ['nullable', 'boolean'],
        ]);
    }
}
