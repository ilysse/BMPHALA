<?php
require __DIR__.'/vendor/autoload.php';
$app = require_once __DIR__.'/bootstrap/app.php';
$app->make(Illuminate\Contracts\Console\Kernel::class)->bootstrap();

$company = App\Models\Company::first();
if ($company) {
    App\Models\NotificationTemplate::create([
        'company_id' => $company->id,
        'name' => 'Default Order Placed',
        'event_type' => 'order_placed',
        'channels' => ['push', 'in_app'],
        'title_template' => 'New Order Placed',
        'body_template' => 'Order {order_id} was placed by {customer_name} for {total_amount} DH.',
        'is_active' => true
    ]);
    echo "Template created successfully.\n";
} else {
    echo "No company found.\n";
}
