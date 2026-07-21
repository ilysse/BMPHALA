<?php

namespace Database\Seeders;

use App\Models\NotificationTemplate;
use App\Models\User;
use Illuminate\Database\Seeder;

class NotificationTemplateSeeder extends Seeder
{
    public function run(): void
    {
        $companyId = User::first()?->company_id ?? 'default-company';

        $templates = [
            [
                'event_type' => 'order_placed',
                'title_template' => 'New Order {{order_number}}',
                'body_template' => 'Order {{order_number}} placed by {{retailer_name}} for {{amount}} DH',
                'channel' => 'push',
            ],
            [
                'event_type' => 'order_shipped',
                'title_template' => 'Order {{order_number}} Shipped',
                'body_template' => 'Your order {{order_number}} is on its way with {{distributor_name}}',
                'channel' => 'push',
            ],
            [
                'event_type' => 'payment_received',
                'title_template' => 'Payment of {{amount}} DH Received',
                'body_template' => 'Payment of {{amount}} DH received for order {{order_number}}. Balance: {{balance}} DH',
                'channel' => 'push',
            ],
            [
                'event_type' => 'product_new',
                'title_template' => 'New Product: {{product_name}}',
                'body_template' => '{{product_name}} is now available in our catalog at {{price}} DH',
                'channel' => 'push',
            ],
            [
                'event_type' => 'product_restocked',
                'title_template' => '{{product_name}} Restocked',
                'body_template' => '{{product_name}} is back in stock with {{quantity}} units available',
                'channel' => 'push',
            ],
            [
                'event_type' => 'promotion_new',
                'title_template' => 'New Promotion Available',
                'body_template' => '{{promotion_name}}: Get {{discount}} off on selected products',
                'channel' => 'push',
            ],
            [
                'event_type' => 'promotion_updated',
                'title_template' => 'Promotion Updated',
                'body_template' => '{{promotion_name}} has been updated. Check the latest deals!',
                'channel' => 'push',
            ],
        ];

        foreach ($templates as $template) {
            NotificationTemplate::updateOrCreate(
                [
                    'company_id' => $companyId,
                    'event_type' => $template['event_type'],
                ],
                array_merge($template, [
                    'is_active' => true,
                ])
            );
        }
    }
}
