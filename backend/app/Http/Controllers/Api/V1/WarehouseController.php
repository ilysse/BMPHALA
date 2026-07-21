<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Models\Warehouse;
use Illuminate\Http\Request;
use Illuminate\Support\Str;

class WarehouseController extends Controller
{
    public function index()
    {
        $warehouses = Warehouse::all();
        return response()->json([
            'success' => true,
            'message' => 'Warehouses retrieved.',
            'data' => $warehouses,
            'meta' => null,
            'errors' => null
        ]);
    }

    public function store(Request $request)
    {
        $data = $request->validate([
            'name' => 'required|string|max:255',
            'location' => 'nullable|string|max:500',
        ]);

        $warehouse = Warehouse::create(array_merge($data, [
            'id' => (string) Str::ulid(),
            'is_active' => true,
        ]));

        return response()->json([
            'success' => true,
            'message' => 'Warehouse created.',
            'data' => $warehouse,
            'meta' => null,
            'errors' => null
        ], 201);
    }

    public function show(string $warehouse)
    {
        $warehouse = Warehouse::findOrFail($warehouse);

        return response()->json([
            'success' => true,
            'message' => 'Warehouse retrieved.',
            'data' => $warehouse,
            'meta' => null,
            'errors' => null
        ]);
    }

    public function update(Request $request, string $warehouse)
    {
        $warehouse = Warehouse::findOrFail($warehouse);

        $data = $request->validate([
            'name' => 'sometimes|required|string|max:255',
            'location' => 'nullable|string|max:500',
            'is_active' => 'nullable|boolean',
        ]);

        $warehouse->update($data);

        return response()->json([
            'success' => true,
            'message' => 'Warehouse updated.',
            'data' => $warehouse,
            'meta' => null,
            'errors' => null
        ]);
    }

    public function destroy(string $warehouse)
    {
        $warehouse = Warehouse::findOrFail($warehouse);
        $warehouse->delete();
        return response()->json([
            'success' => true,
            'message' => 'Warehouse deleted.',
            'data' => null,
            'meta' => null,
            'errors' => null
        ]);
    }
}
