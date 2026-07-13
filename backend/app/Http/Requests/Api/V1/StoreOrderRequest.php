<?php

namespace App\Http\Requests\Api\V1;

use Illuminate\Foundation\Http\FormRequest;

class StoreOrderRequest extends FormRequest
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
            'items'               => ['required', 'array', 'min:1'],
            'items.*.product_id'  => ['required', 'string', 'exists:products,id'],
            'items.*.quantity'    => ['required', 'integer', 'min:1'],
            'delivery_address'    => ['nullable', 'string', 'max:500'],
            'delivery_latitude'   => ['nullable', 'numeric', 'between:-90,90'],
            'delivery_longitude'  => ['nullable', 'numeric', 'between:-180,180'],
            'notes'              => ['nullable', 'string', 'max:1000'],
        ];
    }
}
