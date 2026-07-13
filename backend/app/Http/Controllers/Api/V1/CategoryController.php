<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Models\Category;
use App\Http\Resources\Api\V1\CategoryResource;
use Illuminate\Http\Request;
use Illuminate\Support\Str;

class CategoryController extends Controller
{
    public function index()
    {
        $categories = Category::orderBy('sort_order')->get();
        return response()->json([
            'success' => true,
            'message' => 'Categories retrieved.',
            'data' => CategoryResource::collection($categories),
            'meta' => null,
            'errors' => null
        ]);
    }

    public function store(Request $request)
    {
        $data = $request->validate([
            'name' => 'required|string|max:255',
            'parent_id' => 'nullable|exists:categories,id',
            'image_url' => 'nullable|string',
            'sort_order' => 'nullable|integer',
        ]);

        $category = Category::create(array_merge($data, [
            'id' => (string) Str::ulid(),
            'slug' => Str::slug($data['name']),
            'is_active' => true,
        ]));

        return response()->json([
            'success' => true,
            'message' => 'Category created.',
            'data' => new CategoryResource($category),
            'meta' => null,
            'errors' => null
        ], 201);
    }

    public function show(Category $category)
    {
        return response()->json([
            'success' => true,
            'message' => 'Category retrieved.',
            'data' => new CategoryResource($category),
            'meta' => null,
            'errors' => null
        ]);
    }

    public function update(Request $request, Category $category)
    {
        $data = $request->validate([
            'name' => 'sometimes|required|string|max:255',
            'parent_id' => 'nullable|exists:categories,id',
            'image_url' => 'nullable|string',
            'sort_order' => 'nullable|integer',
            'is_active' => 'nullable|boolean',
        ]);

        if (isset($data['name'])) {
            $data['slug'] = Str::slug($data['name']);
        }

        $category->update($data);

        return response()->json([
            'success' => true,
            'message' => 'Category updated.',
            'data' => new CategoryResource($category),
            'meta' => null,
            'errors' => null
        ]);
    }

    public function destroy(Category $category)
    {
        $category->delete();
        return response()->json([
            'success' => true,
            'message' => 'Category deleted.',
            'data' => null,
            'meta' => null,
            'errors' => null
        ]);
    }
}
