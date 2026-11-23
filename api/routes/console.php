<?php

use Illuminate\Foundation\Inspiring;
use Illuminate\Support\Facades\Artisan;
use Illuminate\Support\Facades\Schedule;

Artisan::command('inspire', function () {
    $this->comment(Inspiring::quote());
})->purpose('Display an inspiring quote');

// Orders nobody acted on get cancelled or handed back (see config/delivery.php).
// Needs the scheduler running: `* * * * * php artisan schedule:run` in production.
Schedule::command('orders:expire-stale')->everyMinute()->withoutOverlapping();
