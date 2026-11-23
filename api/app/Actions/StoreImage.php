<?php

namespace App\Actions;

use GdImage;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\Storage;
use Illuminate\Support\Str;
use Illuminate\Validation\ValidationException;

/**
 * Turns an uploaded photo into two WebP files: a full-size one for detail
 * screens and a square thumbnail for lists.
 *
 * The upload is never stored as received. It is decoded and encoded again,
 * which drops metadata (GPS position, camera data) and means a file that is
 * not really a picture, or a picture hiding something else, cannot be served.
 */
class StoreImage
{
    /** Largest side we accept, so decoding fits in PHP's memory limit. */
    public const MAX_SIDE = 4096;

    private const ACCEPTED_TYPES = [IMAGETYPE_JPEG, IMAGETYPE_PNG, IMAGETYPE_WEBP];

    /**
     * @param  UploadedFile|string  $source  An upload, or raw image bytes (used by the seeder).
     * @param  string  $folder  Directory inside the images disk, e.g. `restaurants`.
     * @return string Path of the full-size image; the thumbnail is `Models\Concerns\HasImage::thumbnailPathFor()` of it.
     */
    public function handle(UploadedFile|string $source, string $folder): string
    {
        $binary = $source instanceof UploadedFile ? (string) $source->get() : $source;

        $image = $this->decode($binary);

        if ($source instanceof UploadedFile && $source->getMimeType() === 'image/jpeg') {
            $image = $this->upright($image, $source->getRealPath());
        }

        $name = Str::uuid()->toString();
        $disk = Storage::disk(config('delivery.images.disk'));

        $full = $this->encode($this->fit($image, (int) config('delivery.images.full_side')));
        $thumbnail = $this->encode($this->square($image, (int) config('delivery.images.thumbnail_side')));

        $disk->put("{$folder}/{$name}.webp", $full, 'public');
        $disk->put("{$folder}/{$name}_thumb.webp", $thumbnail, 'public');

        return "{$folder}/{$name}.webp";
    }

    private function decode(string $binary): GdImage
    {
        $info = @getimagesizefromstring($binary);

        if ($info === false || ! in_array($info[2], self::ACCEPTED_TYPES, true)) {
            $this->reject('El archivo no es una imagen válida. Usa JPG, PNG o WebP.');
        }

        [$width, $height] = $info;

        if ($width > self::MAX_SIDE || $height > self::MAX_SIDE || ! $this->fitsInMemory($width, $height)) {
            $this->reject('La imagen es demasiado grande. Reduce su tamaño a menos de '.self::MAX_SIDE.' píxeles por lado.');
        }

        $image = @imagecreatefromstring($binary);

        if ($image === false) {
            $this->reject('No pudimos leer la imagen. Prueba con otra.');
        }

        return $image;
    }

    /**
     * A decoded bitmap takes roughly 5 bytes per pixel while we resize it.
     */
    private function fitsInMemory(int $width, int $height): bool
    {
        $limit = $this->memoryLimitBytes();

        return $limit === -1 || ($width * $height * 5) + memory_get_usage() < $limit * 0.8;
    }

    private function memoryLimitBytes(): int
    {
        $value = trim((string) ini_get('memory_limit'));

        if ($value === '-1') {
            return -1;
        }

        $number = (int) $value;

        return match (strtolower(substr($value, -1))) {
            'g' => $number * 1024 ** 3,
            'm' => $number * 1024 ** 2,
            'k' => $number * 1024,
            default => $number,
        };
    }

    /**
     * Phones store photos sideways and record the real orientation in EXIF.
     */
    private function upright(GdImage $image, string|false $path): GdImage
    {
        if ($path === false || ! function_exists('exif_read_data')) {
            return $image;
        }

        $exif = @exif_read_data($path);
        $angle = match ($exif['Orientation'] ?? 1) {
            3 => 180,
            6 => -90,
            8 => 90,
            default => 0,
        };

        if ($angle === 0) {
            return $image;
        }

        return imagerotate($image, $angle, 0) ?: $image;
    }

    /** Scales down so the longest side is at most $side, keeping the proportions. */
    private function fit(GdImage $image, int $side): GdImage
    {
        $width = imagesx($image);
        $height = imagesy($image);
        $scale = min(1, $side / max($width, $height));

        $target = $this->canvas(max(1, (int) round($width * $scale)), max(1, (int) round($height * $scale)));
        imagecopyresampled($target, $image, 0, 0, 0, 0, imagesx($target), imagesy($target), $width, $height);

        return $target;
    }

    /** A $side × $side thumbnail cropped from the centre. */
    private function square(GdImage $image, int $side): GdImage
    {
        $width = imagesx($image);
        $height = imagesy($image);
        $crop = min($width, $height);

        $target = $this->canvas($side, $side);
        imagecopyresampled(
            $target, $image,
            0, 0, intdiv($width - $crop, 2), intdiv($height - $crop, 2),
            $side, $side, $crop, $crop,
        );

        return $target;
    }

    /** A transparent canvas, so PNGs with transparency keep it. */
    private function canvas(int $width, int $height): GdImage
    {
        $canvas = imagecreatetruecolor($width, $height);
        imagealphablending($canvas, false);
        imagesavealpha($canvas, true);
        imagefill($canvas, 0, 0, imagecolorallocatealpha($canvas, 0, 0, 0, 127));

        return $canvas;
    }

    private function encode(GdImage $image): string
    {
        ob_start();
        imagewebp($image, null, (int) config('delivery.images.quality'));

        return (string) ob_get_clean();
    }

    /**
     * @return never
     */
    private function reject(string $message): void
    {
        throw ValidationException::withMessages(['image' => $message]);
    }
}
