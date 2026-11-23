<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Run the migrations.
     */
    public function up(): void
    {
        Schema::table('orders', function (Blueprint $table) {
            // When the order last changed status; the timeouts count from here.
            $table->timestamp('status_changed_at')->nullable()->index()->after('status');
            // Why it was rejected, cancelled or not delivered, and who decided.
            $table->string('status_reason')->nullable()->after('status_changed_at');
            $table->string('status_actor')->nullable()->after('status_reason');
            // When it became available to couriers (or came back after being released).
            $table->timestamp('available_at')->nullable()->index()->after('status_actor');
            // When the current courier took it.
            $table->timestamp('claimed_at')->nullable()->after('courier_id');
        });

        DB::table('orders')->update(['status_changed_at' => DB::raw('updated_at')]);
        DB::table('orders')->where('status', 'ready')->update(['available_at' => DB::raw('updated_at')]);
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::table('orders', function (Blueprint $table) {
            $table->dropColumn(['status_changed_at', 'status_reason', 'status_actor', 'available_at', 'claimed_at']);
        });
    }
};
