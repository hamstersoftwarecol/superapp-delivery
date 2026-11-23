<?php

namespace App\Models\Concerns;

use Illuminate\Support\Facades\Storage;

/**
 * For models with an `image_path` column pointing at a photo on the images
 * disk (see App\Actions\StoreImage).
 *
 * @property string|null $image_path
 */
trait HasImage
{
    /** The square thumbnail is stored next to the full image. */
    public static function thumbnailPathFor(string $path): string
    {
        return preg_replace('/\.webp$/', '_thumb.webp', $path) ?? $path;
    }

    public function imageUrl(): ?string
    {
        return $this->image_path === null ? null : self::urlFor($this->image_path);
    }

    public function thumbnailUrl(): ?string
    {
        return $this->image_path === null ? null : self::urlFor(self::thumbnailPathFor($this->image_path));
    }

    /**
     * Local disks give a relative URL; it becomes absolute using the host of the
     * current request, so a phone or emulator gets an address it can reach.
     * Cloud disks give a full URL already.
     */
    private static function urlFor(string $path): string
    {
        $url = Storage::disk(config('delivery.images.disk'))->url($path);

        return str_starts_with($url, '/') ? url($url) : $url;
    }
}
