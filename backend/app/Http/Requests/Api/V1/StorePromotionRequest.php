<?php

namespace App\Http\Requests\Api\V1;

use Illuminate\Foundation\Http\FormRequest;

class StorePromotionRequest extends FormRequest
{
    /**
     * Determine if the user is authorized to make this request.
     */
    public function authorize(): bool
    {
        return true;
    }

    /**
     * Get the validation rules that apply to the request.
     *
     * @return array<string, \Illuminate\Contracts\Validation\ValidationRule|array<mixed>|string>
     */
    public function rules(): array
    {
        return [
            'name'          => ['required', 'string', 'max:255'],
            'type'          => ['required', 'string', 'in:percentage,fixed,bulk_tier,buy_x_get_y'],
            'configuration' => ['required', 'array'],
            'is_active'     => ['nullable', 'boolean'],
            'start_date'    => ['nullable', 'date'],
            'end_date'      => ['nullable', 'date', 'after:start_date'],
            'priority'      => ['nullable', 'integer'],
            'configuration.product_ids' => ['nullable', 'array'],
            'configuration.product_ids.*' => ['string', 'exists:products,id'],
            'configuration.brand_ids' => ['nullable', 'array'],
            'configuration.brand_ids.*' => ['string', 'exists:brands,id'],
            'configuration.category_ids' => ['nullable', 'array'],
            'configuration.category_ids.*' => ['string', 'exists:categories,id'],
        ];
    }
}
