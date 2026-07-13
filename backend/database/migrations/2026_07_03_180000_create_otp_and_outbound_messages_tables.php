<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('otp_challenges', function (Blueprint $table) {
            $table->ulid('id')->primary();
            $table->ulid('company_id')->nullable();
            $table->string('phone');
            $table->string('normalized_phone');
            $table->string('channel', 20);
            $table->string('purpose')->default('login');
            $table->string('code_hash');
            $table->timestamp('expires_at');
            $table->timestamp('consumed_at')->nullable();
            $table->unsignedTinyInteger('attempts')->default(0);
            $table->unsignedTinyInteger('resend_count')->default(0);
            $table->string('ip_address')->nullable();
            $table->json('metadata')->nullable();
            $table->timestamps();

            $table->index(['normalized_phone', 'channel', 'purpose']);
            $table->index(['company_id', 'created_at']);
        });

        Schema::create('outbound_messages', function (Blueprint $table) {
            $table->ulid('id')->primary();
            $table->string('channel', 20);
            $table->string('to_phone');
            $table->text('body');
            $table->string('status', 20)->default('pending');
            $table->string('provider', 50)->default('database_gateway');
            $table->string('provider_reference')->nullable();
            $table->text('error')->nullable();
            $table->timestamp('available_at')->nullable();
            $table->timestamp('sent_at')->nullable();
            $table->timestamp('delivered_at')->nullable();
            $table->json('metadata')->nullable();
            $table->timestamps();

            $table->index(['channel', 'status', 'available_at']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('outbound_messages');
        Schema::dropIfExists('otp_challenges');
    }
};
