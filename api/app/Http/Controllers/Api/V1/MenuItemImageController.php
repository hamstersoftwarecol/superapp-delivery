<?php

namespace App\Http\Controllers\Api\V1;

use App\Actions\DeleteImage;
use App\Actions\StoreImage;
use App\Http\Controllers\Controller;
use App\Http\Requests\Api\V1\UploadImageRequest;
use App\Http\Resources\MenuItemResource;
use App\Models\MenuItem;
use Illuminate\Support\Facades\Gate;

class MenuItemImageController extends Controller
{
    public function store(UploadImageRequest $request, MenuItem $menuItem, StoreImage $storeImage, DeleteImage $deleteImage): MenuItemResource
    {
        Gate::authorize('update', $menuItem->restaurant);

        $previous = $menuItem->image_path;
        $path = $storeImage->handle($request->file('image'), 'menu-items');

        try {
            $menuItem->forceFill(['image_path' => $path])->save();
        } catch (\Throwable $error) {
            $deleteImage->handle($path);

            throw $error;
        }

        $deleteImage->handle($previous);

        return new MenuItemResource($menuItem);
    }

    public function destroy(MenuItem $menuItem, DeleteImage $deleteImage): MenuItemResource
    {
        Gate::authorize('update', $menuItem->restaurant);

        $deleteImage->handle($menuItem->image_path);
        $menuItem->forceFill(['image_path' => null])->save();

        return new MenuItemResource($menuItem);
    }
}
