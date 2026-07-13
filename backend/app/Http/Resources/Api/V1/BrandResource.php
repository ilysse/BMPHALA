<?php

namespace App\Http\Resources\Api\V1;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

class BrandResource extends JsonResource
{
    /**
     * Transform the resource into an array.
     *
     * @return array<string, mixed>
     */
    public function toArray(Request $request): array
    {
        return [
            'id'       => $this->id,
            'name'     => $this->name,
            'slug'     => $this->slug,
            'logo_url' => $this->logo_url ? (str_starts_with($this->logo_url, 'http') ? $this->logo_url : url('storage/' . $this->logo_url)) : null,
            'is_active' => $this->is_active,
        ];
    }
}
