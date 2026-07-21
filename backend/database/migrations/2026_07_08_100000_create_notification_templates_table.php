<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('notification_templates', function (Blueprint $table) {
            $table->string('id')->primary();
            $table->string('company_id')->index();
            $table->string('event_type');
            $table->string('title_template');
            $table->text('body_template');
            $table->string('channel')->default('push');
            $table->boolean('is_active')->default(true);
            $table->timestamps();

            $table->unique(['company_id', 'event_type']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('notification_templates');
    }
};
