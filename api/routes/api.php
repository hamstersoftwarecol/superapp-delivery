<?php

use App\Http\Controllers\Api\V1\AuthController;
use App\Http\Controllers\Api\V1\AvailableOrderController;
use App\Http\Controllers\Api\V1\MenuItemController;
use App\Http\Controllers\Api\V1\OrderClaimController;
use App\Http\Controllers\Api\V1\OrderController;
use App\Http\Controllers\Api\V1\OrderStatusController;
use App\Http\Controllers\Api\V1\RestaurantController;
use Illuminate\Support\Facades\Route;

Route::prefix('v1')->group(function () {
    Route::post('auth/register', [AuthController::class, 'register'])->middleware('throttle:10,1');
    Route::post('auth/login', [AuthController::class, 'login'])->middleware('throttle:5,1');

    Route::get('restaurants', [RestaurantController::class, 'index']);

    Route::middleware('auth:sanctum')->group(function () {
        Route::post('auth/logout', [AuthController::class, 'logout']);
        Route::get('me', [AuthController::class, 'me']);

        Route::get('owner/restaurants', [RestaurantController::class, 'mine']);
        Route::post('restaurants', [RestaurantController::class, 'store']);
        Route::match(['put', 'patch'], 'restaurants/{restaurant}', [RestaurantController::class, 'update']);
        Route::post('restaurants/{restaurant}/menu-items', [MenuItemController::class, 'store']);
        Route::match(['put', 'patch'], 'menu-items/{menuItem}', [MenuItemController::class, 'update']);
        Route::delete('menu-items/{menuItem}', [MenuItemController::class, 'destroy']);

        Route::get('courier/available-orders', AvailableOrderController::class);

        Route::get('orders', [OrderController::class, 'index']);
        Route::post('orders', [OrderController::class, 'store']);
        Route::get('orders/{order}', [OrderController::class, 'show']);
        Route::patch('orders/{order}/status', OrderStatusController::class);
        Route::post('orders/{order}/claim', OrderClaimController::class);
    });

    Route::get('restaurants/{restaurant}', [RestaurantController::class, 'show']);
});
