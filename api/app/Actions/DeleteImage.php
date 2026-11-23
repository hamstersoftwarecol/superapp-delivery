<?php

namespace App\Actions;

use App\Models\Concerns\HasImage;
use Illuminate\Support\Facades\Storage;

class DeleteImage
{
    /**
     * Removes both sizes of an image. Safe to call with `null` or with files
     * that are already gone.
     */
    public function handle(?string $path): void
    {
        if ($path === null || $path === '') {
            return;
        }

        Storage::disk(config('delivery.images.disk'))->delete([
            $path,
            HasImage::thumbnailPathFor($path),
        ]);
    }
}
