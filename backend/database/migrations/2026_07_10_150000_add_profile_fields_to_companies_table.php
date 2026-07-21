<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('companies', function (Blueprint $table) {
            $table->string('email')->nullable()->after('name');
            $table->string('phone', 30)->nullable()->after('email');
            $table->string('tax_id', 100)->nullable()->after('phone');
            $table->string('logo_url')->nullable()->after('tax_id');
            $table->string('address', 500)->nullable()->after('logo_url');
        });
    }

    public function down(): void
    {
        Schema::table('companies', function (Blueprint $table) {
            $table->dropColumn(['email', 'phone', 'tax_id', 'logo_url', 'address']);
        });
    }
};
