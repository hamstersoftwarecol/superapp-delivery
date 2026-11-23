<?php

namespace App\Http\Requests\Api\V1;

use Illuminate\Foundation\Http\FormRequest;

class SaveMenuItemRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    /**
     * @return array<string, mixed>
     */
    public function rules(): array
    {
        $presence = $this->isMethod('POST') ? 'required' : 'sometimes';

        return [
            'name' => [$presence, 'string', 'max:255'],
            'description' => ['nullable', 'string', 'max:2000'],
            'price_cents' => [$presence, 'integer', 'min:1', 'max:100000000'],
            'is_available' => ['sometimes', 'boolean'],
        ];
    }
}
