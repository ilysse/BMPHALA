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
        // 1. Orders
        Schema::create('orders', function (Blueprint $table) {
            $table->ulid('id')->primary();
            $table->ulid('company_id');
            $table->string('order_number')->nullable();
            $table->ulid('retailer_id');
            $table->ulid('distributor_id')->nullable();
            $table->string('status')->default('pending'); // pending, confirmed, processing, assigned, in_transit, out_for_delivery, delivered, cancelled, returned
            $table->string('payment_status')->default('unpaid'); // unpaid, partially_paid, paid
            $table->decimal('total_amount', 15, 2);
            $table->decimal('discount_amount', 15, 2)->default(0.00);
            $table->decimal('tax_amount', 15, 2)->default(0.00);
            $table->decimal('shipping_amount', 15, 2)->default(0.00);
            $table->decimal('grand_total', 15, 2);
            $table->text('notes')->nullable();
            $table->string('delivery_address')->nullable();
            $table->string('delivery_gps')->nullable();
            $table->string('delivery_signature_url')->nullable();
            $table->string('delivery_photo_url')->nullable();
            $table->timestamp('expected_delivery_at')->nullable();
            $table->timestamp('actual_delivery_at')->nullable();
            $table->timestamps();

            $table->foreign('company_id')->references('id')->on('companies')->onDelete('cascade');
            $table->foreign('retailer_id')->references('id')->on('users')->onDelete('cascade');
            $table->foreign('distributor_id')->references('id')->on('users')->onDelete('set null');
        });

        // 2. Order Items
        Schema::create('order_items', function (Blueprint $table) {
            $table->ulid('id')->primary();
            $table->ulid('company_id');
            $table->ulid('order_id');
            $table->ulid('product_id');
            $table->integer('quantity');
            $table->string('product_name')->nullable();
            $table->decimal('unit_price', 15, 2);
            $table->decimal('discount_amount', 15, 2)->default(0.00);
            $table->decimal('total_price', 15, 2);
            $table->timestamps();

            $table->foreign('company_id')->references('id')->on('companies')->onDelete('cascade');
            $table->foreign('order_id')->references('id')->on('orders')->onDelete('cascade');
            $table->foreign('product_id')->references('id')->on('products')->onDelete('cascade');
        });

        // 3. Order History (Status Logs)
        Schema::create('order_history', function (Blueprint $table) {
            $table->ulid('id')->primary();
            $table->ulid('company_id');
            $table->ulid('order_id');
            $table->string('status');
            $table->ulid('changed_by');
            $table->string('notes')->nullable();
            $table->timestamps();

            $table->foreign('company_id')->references('id')->on('companies')->onDelete('cascade');
            $table->foreign('order_id')->references('id')->on('orders')->onDelete('cascade');
            $table->foreign('changed_by')->references('id')->on('users')->onDelete('cascade');
        });

        // 4. Payments
        Schema::create('payments', function (Blueprint $table) {
            $table->ulid('id')->primary();
            $table->ulid('company_id');
            $table->ulid('order_id');
            $table->decimal('amount', 15, 2);
            $table->string('payment_method'); // cash, check, bank_transfer, mobile_money
            $table->string('payment_status')->default('pending'); // pending, completed, failed
            $table->string('transaction_reference')->nullable();
            $table->text('notes')->nullable();
            $table->timestamps();

            $table->foreign('company_id')->references('id')->on('companies')->onDelete('cascade');
            $table->foreign('order_id')->references('id')->on('orders')->onDelete('cascade');
        });

        // 5. Invoices
        Schema::create('invoices', function (Blueprint $table) {
            $table->ulid('id')->primary();
            $table->ulid('company_id');
            $table->ulid('order_id');
            $table->string('invoice_number');
            $table->decimal('amount_due', 15, 2);
            $table->timestamp('due_date')->nullable();
            $table->string('status')->default('unpaid'); // unpaid, paid, overdue, cancelled
            $table->timestamps();

            $table->unique(['company_id', 'invoice_number']);
            $table->foreign('company_id')->references('id')->on('companies')->onDelete('cascade');
            $table->foreign('order_id')->references('id')->on('orders')->onDelete('cascade');
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::dropIfExists('invoices');
        Schema::dropIfExists('payments');
        Schema::dropIfExists('order_history');
        Schema::dropIfExists('order_items');
        Schema::dropIfExists('orders');
    }
};
