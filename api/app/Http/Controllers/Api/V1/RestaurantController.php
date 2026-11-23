<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Http\Requests\Api\V1\SaveRestaurantRequest;
use App\Http\Resources\RestaurantResource;
use App\Models\Restaurant;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\AnonymousResourceCollection;
use Illuminate\Support\Facades\Gate;

class RestaurantController extends Controller
{
    public function index(): AnonymousResourceCollection
    {
        return RestaurantResource::collection(
            Restaurant::query()->visible()->orderBy('name')->paginate(20)
        );
    }

    public function show(Restaurant $restaurant): RestaurantResource
    {
        abort_unless($restaurant->owner->isApproved(), 404);

        return new RestaurantResource(
            $restaurant->load(['menuItems' => fn ($query) => $query->available()->orderBy('name')])
        );
    }

    public function mine(Request $request): AnonymousResourceCollection
    {
        return RestaurantResource::collection(
            $request->user()->restaurants()->with('menuItems')->orderBy('name')->get()
        );
    }

    public function store(SaveRestaurantRequest $request): RestaurantResource
    {
        Gate::authorize('create', Restaurant::class);

        $restaurant = new Restaurant($request->validated());
        $restaurant->owner()->associate($request->user());
        $restaurant->save();

        return new RestaurantResource($restaurant);
    }

    public function update(SaveRestaurantRequest $request, Restaurant $restaurant): RestaurantResource
    {
        Gate::authorize('update', $restaurant);

        $restaurant->update($request->validated());

        return new RestaurantResource($restaurant);
    }
}
