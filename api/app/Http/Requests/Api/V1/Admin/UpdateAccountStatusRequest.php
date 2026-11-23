<?php

namespace App\Http\Requests\Api\V1\Admin;

use App\Enums\AccountStatus;
use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;

class UpdateAccountStatusRequest extends FormRequest
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
        return [
            'status' => ['required', Rule::enum(AccountStatus::class)->only([AccountStatus::Approved, AccountStatus::Suspended])],
            'note' => ['nullable', 'string', 'max:255'],
        ];
    }
}
