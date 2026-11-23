<?php

use App\Http\Controllers\Api\V1\Admin\AccountController;
use App\Http\Controllers\Api\V1\Admin\AccountStatusController;
use App\Http\Controllers\Api\V1\AuthController;
use App\Http\Controllers\Api\V1\AvailableOrderController;
use App\Http\Controllers\Api\V1\MenuItemController;
use App\Http\Controllers\Api\V1\MenuItemImageController;
use App\Http\Controllers\Api\V1\OrderClaimController;
use App\Http\Controllers\Api\V1\OrderController;
use App\Http\Controllers\Api\V1\OrderReleaseController;
use App\Http\Controllers\Api\V1\OrderStatusController;
use App\Http\Controllers\Api\V1\RestaurantController;
use App\Http\Controllers\Api\V1\RestaurantImageController;
use Illuminate\Support\Facades\Route;

Route::prefix('v1')->group(function () {
    Route::post('auth/register', [AuthController::class, 'register'])->middleware('throttle:10,1');
    Route::post('auth/login', [AuthController::class, 'login'])->middleware('throttle:5,1');
    Route::post('auth/forgot-password', [AuthController::class, 'forgotPassword'])->middleware('throttle:5,1');
    Route::post('auth/reset-password', [AuthController::class, 'resetPassword'])->middleware('throttle:10,1');

    Route::get('restaurants', [RestaurantController::class, 'index']);

    Route::middleware('auth:sanctum')->group(function () {
        // Reachable while pending or suspended, so the apps can explain why the account is blocked.
        Route::post('auth/logout', [AuthController::class, 'logout']);
        Route::get('me', [AuthController::class, 'me']);

        // A pending restaurant may prepare its profile and menu; customers cannot see it until approved.
        Route::middleware('active:pending-ok')->group(function () {
            Route::get('owner/restaurants', [RestaurantController::class, 'mine']);
            Route::post('restaurants', [RestaurantController::class, 'store']);
            Route::match(['put', 'patch'], 'restaurants/{restaurant}', [RestaurantController::class, 'update']);
            Route::post('restaurants/{restaurant}/menu-items', [MenuItemController::class, 'store']);
            Route::match(['put', 'patch'], 'menu-items/{menuItem}', [MenuItemController::class, 'update']);
            Route::delete('menu-items/{menuItem}', [MenuItemController::class, 'destroy']);

            Route::post('restaurants/{restaurant}/image', [RestaurantImageController::class, 'store'])->middleware('throttle:30,1');
            Route::delete('restaurants/{restaurant}/image', [RestaurantImageController::class, 'destroy']);
            Route::post('menu-items/{menuItem}/image', [MenuItemImageController::class, 'store'])->middleware('throttle:60,1');
            Route::delete('menu-items/{menuItem}/image', [MenuItemImageController::class, 'destroy']);
        });

        Route::middleware('active')->group(function () {
            Route::get('courier/available-orders', AvailableOrderController::class);

            Route::get('orders', [OrderController::class, 'index']);
            Route::post('orders', [OrderController::class, 'store']);
            Route::get('orders/{order}', [OrderController::class, 'show']);
            Route::patch('orders/{order}/status', OrderStatusController::class);
            Route::post('orders/{order}/claim', OrderClaimController::class);
            Route::post('orders/{order}/release', OrderReleaseController::class);

            Route::prefix('admin')->group(function () {
                Route::get('accounts', [AccountController::class, 'index']);
                Route::patch('accounts/{user}/status', AccountStatusController::class);
            });
        });
    });

    Route::get('restaurants/{restaurant}', [RestaurantController::class, 'show']);
});
