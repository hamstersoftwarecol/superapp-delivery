<?php

/*
|--------------------------------------------------------------------------
| Order timeouts
|--------------------------------------------------------------------------
|
| How long an order may sit without anyone acting before the platform steps
| in (see `php artisan orders:expire-stale`, run every minute by the scheduler).
|
*/

return [
    // The restaurant never accepted or rejected the order.
    'pending_timeout_minutes' => (int) env('ORDER_PENDING_TIMEOUT_MINUTES', 10),

    // The order is ready and no courier is available to take it.
    'unclaimed_timeout_minutes' => (int) env('ORDER_UNCLAIMED_TIMEOUT_MINUTES', 30),

    // A courier took the order but never picked it up: it goes back to the pool.
    'claim_timeout_minutes' => (int) env('ORDER_CLAIM_TIMEOUT_MINUTES', 20),
];
