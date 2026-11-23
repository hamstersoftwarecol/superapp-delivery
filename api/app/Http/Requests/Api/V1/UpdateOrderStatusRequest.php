<?php

namespace App\Http\Requests\Api\V1;

use App\Enums\OrderStatus;
use App\Models\Order;
use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;

class UpdateOrderStatusRequest extends FormRequest
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
            'status' => ['required', Rule::enum(OrderStatus::class)],
            'reason' => [$this->reasonIsRequired() ? 'required' : 'nullable', 'string', 'max:255'],
        ];
    }

    /**
     * @return array<string, string>
     */
    public function messages(): array
    {
        return ['reason.required' => 'Indica el motivo.'];
    }

    public function status(): OrderStatus
    {
        return OrderStatus::from($this->validated('status'));
    }

    public function reason(): ?string
    {
        $reason = $this->validated('reason');

        return is_string($reason) && trim($reason) !== '' ? trim($reason) : null;
    }

    /**
     * Rejecting, cancelling and failing a delivery affect someone else, so
     * they must explain themselves. A customer cancelling their own pending
     * order does not have to.
     */
    private function reasonIsRequired(): bool
    {
        $status = OrderStatus::tryFrom((string) $this->input('status'));
        $order = $this->route('order');

        if ($status === null || ! $status->needsReason()) {
            return false;
        }

        $isCustomerCancelling = $status === OrderStatus::Cancelled
            && $order instanceof Order
            && $order->customer_id === $this->user()?->id;

        return ! $isCustomerCancelling;
    }
}
