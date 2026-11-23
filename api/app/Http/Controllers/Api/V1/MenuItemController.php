<?php

namespace App\Http\Controllers\Api\V1;

use App\Actions\DeleteImage;
use App\Http\Controllers\Controller;
use App\Http\Requests\Api\V1\SaveMenuItemRequest;
use App\Http\Resources\MenuItemResource;
use App\Models\MenuItem;
use App\Models\Restaurant;
use Illuminate\Http\Response;
use Illuminate\Support\Facades\Gate;

class MenuItemController extends Controller
{
    public function store(SaveMenuItemRequest $request, Restaurant $restaurant): MenuItemResource
    {
        Gate::authorize('update', $restaurant);

        $menuItem = new MenuItem($request->validated());
        $menuItem->restaurant()->associate($restaurant);
        $menuItem->save();

        return new MenuItemResource($menuItem);
    }

    public function update(SaveMenuItemRequest $request, MenuItem $menuItem): MenuItemResource
    {
        Gate::authorize('update', $menuItem->restaurant);

        $menuItem->update($request->validated());

        return new MenuItemResource($menuItem);
    }

    public function destroy(MenuItem $menuItem, DeleteImage $deleteImage): Response
    {
        Gate::authorize('update', $menuItem->restaurant);

        $deleteImage->handle($menuItem->image_path);
        $menuItem->delete();

        return response()->noContent();
    }
}
