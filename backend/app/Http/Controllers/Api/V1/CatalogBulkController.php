<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Http\Resources\Api\V1\BrandResource;
use App\Http\Resources\Api\V1\CategoryResource;
use App\Http\Resources\Api\V1\ProductResource;
use App\Models\Brand;
use App\Models\Category;
use App\Models\Product;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Str;

class CatalogBulkController extends Controller
{
    public function export(Request $request): JsonResponse
    {
        $type = $request->validate([
            'type' => ['required', 'string', 'in:products,brands,categories'],
        ])['type'];

        if ($type === 'products') {
            $rows = Product::with(['category', 'brand'])
                ->withSum('inventory as stock', 'quantity')
                ->orderBy('name')
                ->get();

            return response()->json([
                'success' => true,
                'message' => 'Products export ready.',
                'data' => ProductResource::collection($rows),
                'meta' => ['type' => $type],
                'errors' => null,
            ]);
        }

        if ($type === 'brands') {
            return response()->json([
                'success' => true,
                'message' => 'Brands export ready.',
                'data' => BrandResource::collection(Brand::orderBy('name')->get()),
                'meta' => ['type' => $type],
                'errors' => null,
            ]);
        }

        return response()->json([
            'success' => true,
            'message' => 'Categories export ready.',
            'data' => CategoryResource::collection(Category::orderBy('sort_order')->orderBy('name')->get()),
            'meta' => ['type' => $type],
            'errors' => null,
        ]);
    }

    public function import(Request $request): JsonResponse
    {
        $data = $request->validate([
            'type' => ['required', 'string', 'in:products,brands,categories'],
            'rows' => ['required', 'array', 'min:1'],
            'rows.*' => ['required', 'array'],
        ]);

        $created = 0;
        $updated = 0;
        $skipped = [];

        foreach ($data['rows'] as $index => $row) {
            try {
                $result = match ($data['type']) {
                    'products' => $this->upsertProduct($row),
                    'brands' => $this->upsertBrand($row),
                    'categories' => $this->upsertCategory($row),
                };
                $result === 'created' ? $created++ : $updated++;
            } catch (\Throwable $exception) {
                $skipped[] = [
                    'row' => $index + 1,
                    'reason' => $exception->getMessage(),
                ];
            }
        }

        return response()->json([
            'success' => true,
            'message' => 'Bulk import completed.',
            'data' => [
                'created' => $created,
                'updated' => $updated,
                'skipped' => $skipped,
            ],
            'meta' => ['type' => $data['type']],
            'errors' => null,
        ]);
    }

    private function upsertProduct(array $row): string
    {
        $sku = trim((string) ($row['sku'] ?? ''));
        $name = trim((string) ($row['name'] ?? ''));

        if ($sku === '' || $name === '') {
            throw new \InvalidArgumentException('Product requires name and sku.');
        }

        $categoryId = $this->categoryId($row['category_id'] ?? null, $row['category'] ?? null);
        $brandId = $this->brandId($row['brand_id'] ?? null, $row['brand'] ?? null);

        $product = Product::firstOrNew(['sku' => $sku]);
        $wasNew = !$product->exists;

        $product->fill([
            'name' => $name,
            'price' => (float) ($row['price'] ?? 0),
            'cost_price' => $row['cost_price'] ?? null,
            'pack_size' => (int) ($row['pack_size'] ?? 1),
            'pack_unit' => $row['pack_unit'] ?? 'pcs',
            'category_id' => $categoryId,
            'brand_id' => $brandId,
            'barcode' => $row['barcode'] ?? null,
            'description' => $row['description'] ?? null,
            'image_url' => $row['image_url'] ?? null,
            'is_active' => $this->boolValue($row['is_active'] ?? true),
        ]);
        $product->save();

        return $wasNew ? 'created' : 'updated';
    }

    private function upsertBrand(array $row): string
    {
        $name = trim((string) ($row['name'] ?? ''));
        if ($name === '') {
            throw new \InvalidArgumentException('Brand requires name.');
        }

        $brand = Brand::firstOrNew(['slug' => Str::slug($name)]);
        $wasNew = !$brand->exists;
        $brand->fill([
            'name' => $name,
            'slug' => Str::slug($name),
            'logo_url' => $row['logo_url'] ?? null,
            'is_active' => $this->boolValue($row['is_active'] ?? true),
        ]);
        $brand->save();

        return $wasNew ? 'created' : 'updated';
    }

    private function upsertCategory(array $row): string
    {
        $name = trim((string) ($row['name'] ?? ''));
        if ($name === '') {
            throw new \InvalidArgumentException('Category requires name.');
        }

        $category = Category::firstOrNew(['slug' => Str::slug($name)]);
        $wasNew = !$category->exists;
        $category->fill([
            'name' => $name,
            'slug' => Str::slug($name),
            'image_url' => $row['image_url'] ?? null,
            'sort_order' => (int) ($row['sort_order'] ?? 0),
            'is_active' => $this->boolValue($row['is_active'] ?? true),
        ]);
        $category->save();

        return $wasNew ? 'created' : 'updated';
    }

    private function categoryId(?string $id, ?string $name): ?string
    {
        if ($id) {
            return $id;
        }

        if (!$name) {
            return null;
        }

        return Category::firstOrCreate(
            ['slug' => Str::slug($name)],
            ['name' => $name, 'is_active' => true, 'sort_order' => 0]
        )->id;
    }

    private function brandId(?string $id, ?string $name): ?string
    {
        if ($id) {
            return $id;
        }

        if (!$name) {
            return null;
        }

        return Brand::firstOrCreate(
            ['slug' => Str::slug($name)],
            ['name' => $name, 'is_active' => true]
        )->id;
    }

    private function boolValue(mixed $value): bool
    {
        if (is_bool($value)) {
            return $value;
        }

        return in_array(strtolower((string) $value), ['1', 'true', 'yes', 'active'], true);
    }
}
