<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Models\Brand;
use App\Http\Resources\Api\V1\BrandResource;
use Illuminate\Http\Request;
use Illuminate\Support\Str;

class BrandController extends Controller
{
    public function index()
    {
        $brands = Brand::all();
        return response()->json([
            'success' => true,
            'message' => 'Brands retrieved.',
            'data' => BrandResource::collection($brands),
            'meta' => null,
            'errors' => null
        ]);
    }

    public function store(Request $request)
    {
        $data = $request->validate([
            'name' => 'required|string|max:255',
            'logo_url' => 'nullable|string',
        ]);

        $brand = Brand::create(array_merge($data, [
            'id' => (string) Str::ulid(),
            'slug' => Str::slug($data['name']),
            'is_active' => true,
        ]));

        return response()->json([
            'success' => true,
            'message' => 'Brand created.',
            'data' => new BrandResource($brand),
            'meta' => null,
            'errors' => null
        ], 201);
    }

    public function show(Brand $brand)
    {
        return response()->json([
            'success' => true,
            'message' => 'Brand retrieved.',
            'data' => new BrandResource($brand),
            'meta' => null,
            'errors' => null
        ]);
    }

    public function update(Request $request, Brand $brand)
    {
        $data = $request->validate([
            'name' => 'sometimes|required|string|max:255',
            'logo_url' => 'nullable|string',
            'is_active' => 'nullable|boolean',
        ]);

        if (isset($data['name'])) {
            $data['slug'] = Str::slug($data['name']);
        }

        $brand->update($data);

        return response()->json([
            'success' => true,
            'message' => 'Brand updated.',
            'data' => new BrandResource($brand),
            'meta' => null,
            'errors' => null
        ]);
    }

    public function destroy(Brand $brand)
    {
        $brand->delete();
        return response()->json([
            'success' => true,
            'message' => 'Brand deleted.',
            'data' => null,
            'meta' => null,
            'errors' => null
        ]);
    }
}
