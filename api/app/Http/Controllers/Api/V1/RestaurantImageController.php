<?php

namespace App\Http\Controllers\Api\V1;

use App\Actions\DeleteImage;
use App\Actions\StoreImage;
use App\Http\Controllers\Controller;
use App\Http\Requests\Api\V1\UploadImageRequest;
use App\Http\Resources\RestaurantResource;
use App\Models\Restaurant;
use Illuminate\Support\Facades\Gate;

class RestaurantImageController extends Controller
{
    public function store(UploadImageRequest $request, Restaurant $restaurant, StoreImage $storeImage, DeleteImage $deleteImage): RestaurantResource
    {
        Gate::authorize('update', $restaurant);

        $previous = $restaurant->image_path;
        $path = $storeImage->handle($request->file('image'), 'restaurants');

        try {
            $restaurant->forceFill(['image_path' => $path])->save();
        } catch (\Throwable $error) {
            $deleteImage->handle($path);

            throw $error;
        }

        $deleteImage->handle($previous);

        return new RestaurantResource($restaurant);
    }

    public function destroy(Restaurant $restaurant, DeleteImage $deleteImage): RestaurantResource
    {
        Gate::authorize('update', $restaurant);

        $deleteImage->handle($restaurant->image_path);
        $restaurant->forceFill(['image_path' => null])->save();

        return new RestaurantResource($restaurant);
    }
}
