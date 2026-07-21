<?php

namespace App\Http\Resources\Api\V1;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

class CategoryResource extends JsonResource
{
    /**
     * Transform the resource into an array.
     *
     * @return array<string, mixed>
     */
    public function toArray(Request $request): array
    {
        return [
            'id'        => $this->id,
            'name'      => $this->name,
            'slug'      => $this->slug,
            'parent_id' => $this->parent_id,
            'image_url' => $this->image_url ? (str_starts_with($this->image_url, 'http') ? $this->image_url : url('storage/' . $this->image_url)) : null,
            'is_active' => $this->is_active,
        ];
    }
}
