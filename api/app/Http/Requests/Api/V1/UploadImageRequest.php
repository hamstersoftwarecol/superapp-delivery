<?php

namespace App\Http\Requests\Api\V1;

use App\Actions\StoreImage;
use Illuminate\Foundation\Http\FormRequest;

class UploadImageRequest extends FormRequest
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
            'image' => [
                'required',
                'file',
                'image',
                'mimes:jpg,jpeg,png,webp',
                'max:'.config('delivery.images.max_kb'),
                'dimensions:min_width=200,min_height=200,max_width='.StoreImage::MAX_SIDE.',max_height='.StoreImage::MAX_SIDE,
            ],
        ];
    }

    /**
     * @return array<string, string>
     */
    public function messages(): array
    {
        $maxMb = round(config('delivery.images.max_kb') / 1024);

        return [
            'image.required' => 'Elige una imagen.',
            'image.uploaded' => "No se pudo subir la imagen. Revisa que pese menos de {$maxMb} MB.",
            'image.image' => 'El archivo no es una imagen válida. Usa JPG, PNG o WebP.',
            'image.mimes' => 'El archivo no es una imagen válida. Usa JPG, PNG o WebP.',
            'image.max' => "La imagen pesa demasiado. El máximo es {$maxMb} MB.",
            'image.dimensions' => 'La imagen debe medir al menos 200 × 200 píxeles y no más de '.StoreImage::MAX_SIDE.' por lado.',
        ];
    }
}
