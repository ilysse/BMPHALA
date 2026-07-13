<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Run the migrations.
     */
    public function up(): void
    {
        // 1. Companies (Tenants)
        Schema::create('companies', function (Blueprint $table) {
            $table->ulid('id')->primary();
            $table->string('name');
            $table->string('status')->default('active'); // active, suspended
            $table->timestamps();
        });

        // 2. Users (Scoped to Company)
        Schema::create('users', function (Blueprint $table) {
            $table->ulid('id')->primary();
            $table->ulid('company_id');
            $table->string('name');
            $table->string('email');
            $table->timestamp('email_verified_at')->nullable();
            $table->string('password');
            $table->string('role')->default('retailer'); // admin, distributor, retailer
            $table->string('status')->default('active'); // active, inactive
            $table->rememberToken();
            $table->json('metadata')->nullable();
            $table->timestamps();

            $table->unique(['company_id', 'email']); // scoped unique email per tenant
            $table->foreign('company_id')->references('id')->on('companies')->onDelete('cascade');
        });

        // 3. Roles (Scoped to Company)
        Schema::create('roles', function (Blueprint $table) {
            $table->ulid('id')->primary();
            $table->ulid('company_id');
            $table->string('name');
            $table->string('description')->nullable();
            $table->timestamps();

            $table->unique(['company_id', 'name']);
            $table->foreign('company_id')->references('id')->on('companies')->onDelete('cascade');
        });

        // 4. Permissions (Scoped to Company)
        Schema::create('permissions', function (Blueprint $table) {
            $table->ulid('id')->primary();
            $table->ulid('company_id');
            $table->string('name');
            $table->string('description')->nullable();
            $table->timestamps();

            $table->unique(['company_id', 'name']);
            $table->foreign('company_id')->references('id')->on('companies')->onDelete('cascade');
        });

        // 5. Role-Permission Pivot (Scoped to Company)
        Schema::create('role_permission', function (Blueprint $table) {
            $table->ulid('company_id');
            $table->ulid('role_id');
            $table->ulid('permission_id');

            $table->primary(['role_id', 'permission_id']);
            $table->foreign('company_id')->references('id')->on('companies')->onDelete('cascade');
            $table->foreign('role_id')->references('id')->on('roles')->onDelete('cascade');
            $table->foreign('permission_id')->references('id')->on('permissions')->onDelete('cascade');
        });

        // 6. User-Role Pivot (Scoped to Company)
        Schema::create('user_role', function (Blueprint $table) {
            $table->ulid('company_id');
            $table->ulid('user_id');
            $table->ulid('role_id');

            $table->primary(['user_id', 'role_id']);
            $table->foreign('company_id')->references('id')->on('companies')->onDelete('cascade');
            $table->foreign('user_id')->references('id')->on('users')->onDelete('cascade');
            $table->foreign('role_id')->references('id')->on('roles')->onDelete('cascade');
        });

        // 7. Password Reset Tokens
        Schema::create('password_reset_tokens', function (Blueprint $table) {
            $table->string('email')->primary();
            $table->string('token');
            $table->timestamp('created_at')->nullable();
        });

        // 8. Sessions
        Schema::create('sessions', function (Blueprint $table) {
            $table->string('id')->primary();
            $table->ulid('user_id')->nullable()->index();
            $table->string('ip_address', 45)->nullable();
            $table->text('user_agent')->nullable();
            $table->longText('payload');
            $table->integer('last_activity')->index();
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::dropIfExists('sessions');
        Schema::dropIfExists('password_reset_tokens');
        Schema::dropIfExists('user_role');
        Schema::dropIfExists('role_permission');
        Schema::dropIfExists('permissions');
        Schema::dropIfExists('roles');
        Schema::dropIfExists('users');
        Schema::dropIfExists('companies');
    }
};
