<?php

namespace App\Http\Resources\Api\V1;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

class ProductResource extends JsonResource
{
    /**
     * Transform the resource into an array.
     *
     * @return array<string, mixed>
     */
    public function toArray(Request $request): array
    {
        $stock = (int) (
            $this->stock
            ?? $this->inventory_sum_quantity
            ?? ($this->relationLoaded('inventory') ? $this->inventory->sum('quantity') : $this->inventory()->sum('quantity'))
        );

        return [
            'id'          => $this->id,
            'category_id' => $this->category_id,
            'brand_id'    => $this->brand_id,
            'name'        => $this->name,
            'description' => $this->description,
            'image_url'   => $this->image_url ? (str_starts_with($this->image_url, 'http') ? $this->image_url : url('storage/' . $this->image_url)) : null,
            'sku'         => $this->sku,
            'barcode'     => $this->barcode,
            'price'       => $this->price,
            'cost_price'  => $this->cost_price,
            'pack_size'   => $this->pack_size,
            'pack_unit'   => $this->pack_unit,
            'stock'       => $stock,
            'quantity'    => $stock,
            'is_active'   => $this->is_active,
            'category'    => new CategoryResource($this->whenLoaded('category')),
            'brand'       => new BrandResource($this->whenLoaded('brand')),
        ];
    }
}
