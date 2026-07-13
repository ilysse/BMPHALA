<?php

namespace Database\Seeders;

use App\Models\Company;
use App\Models\Permission;
use App\Models\Role;
use App\Models\User;
use Illuminate\Database\Console\Seeds\WithoutModelEvents;
use Illuminate\Database\Seeder;
use Illuminate\Support\Str;

class DatabaseSeeder extends Seeder
{
    use WithoutModelEvents;

    /**
     * Seed the application's database.
     */
    public function run(): void
    {
        // ── 1. Create Default Company ────────────────────────────────
        $company = Company::firstOrCreate(
            ['name' => 'BMP Default Company'],
            [
                'id'     => (string) Str::ulid(),
                'status' => 'active',
            ]
        );

        // ── 2. Create System Roles ───────────────────────────────────
        $roleDefinitions = [
            'admin' => 'Full system administrator with all privileges.',
            'retailer' => 'Retail user who places orders and manages their own profile.',
            'distributor' => 'Distributor who manages inventory, warehouses, and fulfills orders.',
            'sales_rep' => 'Sales representative who manages customer relationships and orders.',
        ];

        $roles = [];
        foreach ($roleDefinitions as $name => $description) {
            $roles[$name] = Role::withoutGlobalScopes()->firstOrCreate(
                ['company_id' => $company->id, 'name' => $name],
                [
                    'id'          => (string) Str::ulid(),
                    'company_id'  => $company->id,
                    'description' => $description,
                ]
            );
        }

        // ── 3. Create Basic Permissions ──────────────────────────────
        $permissionNames = [
            'users.view', 'users.create', 'users.update', 'users.delete',
            'roles.view', 'roles.create', 'roles.update', 'roles.delete', 'roles.assign_permissions',
            'products.view', 'products.create', 'products.update', 'products.delete',
            'categories.view', 'categories.create', 'categories.update', 'categories.delete',
            'brands.view', 'brands.create', 'brands.update', 'brands.delete',
            'inventory.view', 'inventory.create', 'inventory.update', 'inventory.adjust',
            'warehouses.view', 'warehouses.create', 'warehouses.update', 'warehouses.delete',
            'orders.view', 'orders.create', 'orders.update', 'orders.cancel', 'orders.approve',
            'payments.view', 'payments.create', 'payments.approve',
            'invoices.view', 'invoices.create', 'invoices.download',
            'promotions.view', 'promotions.create', 'promotions.update', 'promotions.delete',
            'feature_flags.view', 'feature_flags.toggle',
            'audit_logs.view',
            'notifications.view', 'notifications.manage',
            'reports.view', 'reports.export',
            'settings.view', 'settings.update',
        ];

        $permissionIds = [];
        foreach ($permissionNames as $permName) {
            $permission = Permission::withoutGlobalScopes()->firstOrCreate(
                ['company_id' => $company->id, 'name' => $permName],
                [
                    'id'          => (string) Str::ulid(),
                    'company_id'  => $company->id,
                    'description' => ucfirst(str_replace(['.', '_'], [' — ', ' '], $permName)),
                ]
            );
            $permissionIds[] = $permission->id;
        }

        // ── 4. Attach All Permissions to Admin Role ──────────────────
        $adminRole = $roles['admin'];
        $pivotData = [];
        foreach ($permissionIds as $permId) {
            $pivotData[$permId] = ['company_id' => $company->id];
        }
        $adminRole->permissions()->syncWithoutDetaching($pivotData);

        // ── 5. Attach View Permissions to Retailer Role ──────────────
        $retailerPerms = Permission::withoutGlobalScopes()
            ->where('company_id', $company->id)
            ->where(function ($q) {
                $q->where('name', 'like', '%.view')
                  ->orWhere('name', 'orders.create')
                  ->orWhere('name', 'notifications.view');
            })
            ->pluck('id');

        $retailerPivot = [];
        foreach ($retailerPerms as $permId) {
            $retailerPivot[$permId] = ['company_id' => $company->id];
        }
        $roles['retailer']->permissions()->syncWithoutDetaching($retailerPivot);

        // ── 6. Create Users ──────────────────────────────────────────
        $adminUser = User::withoutGlobalScopes()->firstOrCreate(
            ['company_id' => $company->id, 'email' => 'admin@bmp.com'],
            [
                'id'       => (string) Str::ulid(),
                'name'     => 'System Admin',
                'password' => \Illuminate\Support\Facades\Hash::make('password'),
                'role'     => 'admin',
                'status'   => 'active',
            ]
        );
        $adminMetadata = $adminUser->metadata ?? [];
        $adminMetadata['can_collect_cash'] = true;
        $adminUser->forceFill(['metadata' => $adminMetadata])->save();
        $adminUser->roles()->syncWithoutDetaching([$adminRole->id => ['company_id' => $company->id]]);

        $repUser = User::withoutGlobalScopes()->firstOrCreate(
            ['company_id' => $company->id, 'email' => 'rep@bmp.com'],
            [
                'id'       => (string) Str::ulid(),
                'name'     => 'Jean SalesRep',
                'password' => \Illuminate\Support\Facades\Hash::make('password'),
                'role'     => 'sales_rep',
                'status'   => 'active',
                'metadata' => ['phone' => '+33612345678', 'referral_code' => 'REP-JEAN'],
            ]
        );
        $repMetadata = $repUser->metadata ?? [];
        $repMetadata['phone'] = $repMetadata['phone'] ?? '+33612345678';
        $repMetadata['referral_code'] = $repMetadata['referral_code'] ?? 'REP-JEAN';
        $repMetadata['can_collect_cash'] = true;
        $repUser->forceFill(['metadata' => $repMetadata])->save();
        $repUser->roles()->syncWithoutDetaching([$roles['sales_rep']->id => ['company_id' => $company->id]]);

        $retailerUser = User::withoutGlobalScopes()->firstOrCreate(
            ['company_id' => $company->id, 'email' => 'retailer@bmp.com'],
            [
                'id'       => (string) Str::ulid(),
                'name'     => 'Superette Express',
                'password' => \Illuminate\Support\Facades\Hash::make('password'),
                'role'     => 'retailer',
                'status'   => 'active',
                'metadata' => ['phone' => '+33687654321', 'responsible_id' => $repUser->id],
                'latitude' => 48.8566,
                'longitude' => 2.3522,
                'address' => '10 Rue de Rivoli, Paris',
            ]
        );
        $retailerUser->forceFill([
            'latitude' => 48.8566,
            'longitude' => 2.3522,
            'address' => '10 Rue de Rivoli, Paris',
        ])->save();
        $retailerUser->roles()->syncWithoutDetaching([$roles['retailer']->id => ['company_id' => $company->id]]);

        $distributorUser = User::withoutGlobalScopes()->firstOrCreate(
            ['company_id' => $company->id, 'email' => 'distributor@bmp.com'],
            [
                'id'       => (string) Str::ulid(),
                'name'     => 'Logistics Central',
                'password' => \Illuminate\Support\Facades\Hash::make('password'),
                'role'     => 'distributor',
                'status'   => 'active',
                'metadata' => ['phone' => '+33655555555'],
            ]
        );
        $distributorMetadata = $distributorUser->metadata ?? [];
        $distributorMetadata['phone'] = $distributorMetadata['phone'] ?? '+33655555555';
        $distributorMetadata['can_collect_cash'] = true;
        $distributorUser->forceFill(['metadata' => $distributorMetadata])->save();
        $distributorUser->roles()->syncWithoutDetaching([$roles['distributor']->id => ['company_id' => $company->id]]);

        // ── 7. Seed Catalog (Categories & Brands) ─────────────────────
        $beverages = \App\Models\Category::firstOrCreate(
            ['company_id' => $company->id, 'name' => 'Beverages'],
            [
                'id' => (string) Str::ulid(),
                'slug' => 'beverages',
                'image_url' => 'https://images.unsplash.com/photo-1527960656366-ee2a6985a496?w=300&q=80',
                'sort_order' => 1,
            ]
        );

        $waterCategory = \App\Models\Category::firstOrCreate(
            ['company_id' => $company->id, 'name' => 'Water'],
            [
                'id' => (string) Str::ulid(),
                'slug' => 'water',
                'parent_id' => $beverages->id,
                'image_url' => 'https://images.unsplash.com/photo-1548839130-3fd2e29128fd?w=300&q=80',
                'sort_order' => 2,
            ]
        );

        $snacks = \App\Models\Category::firstOrCreate(
            ['company_id' => $company->id, 'name' => 'Snacks'],
            [
                'id' => (string) Str::ulid(),
                'slug' => 'snacks',
                'image_url' => 'https://images.unsplash.com/photo-1599490659283-4487335888df?w=300&q=80',
                'sort_order' => 3,
            ]
        );

        $cocaColaBrand = \App\Models\Brand::firstOrCreate(
            ['company_id' => $company->id, 'name' => 'Coca-Cola'],
            ['id' => (string) Str::ulid(), 'slug' => 'coca-cola', 'logo_url' => 'https://logo.clearbit.com/cocacola.com']
        );
        $laysBrand = \App\Models\Brand::firstOrCreate(
            ['company_id' => $company->id, 'name' => 'Lays'],
            ['id' => (string) Str::ulid(), 'slug' => 'lays', 'logo_url' => 'https://logo.clearbit.com/lays.com']
        );
        $evianBrand = \App\Models\Brand::firstOrCreate(
            ['company_id' => $company->id, 'name' => 'Evian'],
            ['id' => (string) Str::ulid(), 'slug' => 'evian', 'logo_url' => 'https://logo.clearbit.com/evian.com']
        );
        $volvicBrand = \App\Models\Brand::firstOrCreate(
            ['company_id' => $company->id, 'name' => 'Volvic'],
            ['id' => (string) Str::ulid(), 'slug' => 'volvic', 'logo_url' => 'https://logo.clearbit.com/volvic.com']
        );
        $perrierBrand = \App\Models\Brand::firstOrCreate(
            ['company_id' => $company->id, 'name' => 'Perrier'],
            ['id' => (string) Str::ulid(), 'slug' => 'perrier', 'logo_url' => 'https://logo.clearbit.com/perrier.com']
        );

        // ── 8. Seed Products ─────────────────────────────────────────
        $productsData = [
            [
                'name' => 'Coca-Cola Original 330ml',
                'category_id' => $beverages->id,
                'brand_id' => $cocaColaBrand->id,
                'sku' => 'COKE-330',
                'barcode' => '5449000000996',
                'price' => 1.20,
                'cost_price' => 0.80,
                'pack_size' => 24,
                'pack_unit' => 'tray',
                'image_url' => 'https://images.unsplash.com/photo-1622483767028-3f66f32aef97?w=300&q=80',
            ],
            [
                'name' => 'Lays Classic Chips 150g',
                'category_id' => $snacks->id,
                'brand_id' => $laysBrand->id,
                'sku' => 'LAYS-CLASSIC',
                'barcode' => '8710398602008',
                'price' => 2.50,
                'cost_price' => 1.50,
                'pack_size' => 12,
                'pack_unit' => 'box',
                'image_url' => 'https://images.unsplash.com/photo-1566478989037-eec170784d0b?w=300&q=80',
            ],
            // Water Products
            [
                'name' => 'Evian Natural Spring Water 500ml',
                'category_id' => $waterCategory->id,
                'brand_id' => $evianBrand->id,
                'sku' => 'EVIAN-500',
                'barcode' => '3068320055008',
                'price' => 1.50,
                'cost_price' => 0.90,
                'pack_size' => 24,
                'pack_unit' => 'carton',
                'image_url' => 'https://images.unsplash.com/photo-1548839130-3fd2e29128fd?w=300&q=80',
            ],
            [
                'name' => 'Evian Natural Spring Water 1.5L',
                'category_id' => $waterCategory->id,
                'brand_id' => $evianBrand->id,
                'sku' => 'EVIAN-1500',
                'barcode' => '3068320097008',
                'price' => 2.80,
                'cost_price' => 1.70,
                'pack_size' => 12,
                'pack_unit' => 'carton',
                'image_url' => 'https://images.unsplash.com/photo-1548839130-3fd2e29128fd?w=300&q=80',
            ],
            [
                'name' => 'Volvic Natural Mineral Water 1L',
                'category_id' => $waterCategory->id,
                'brand_id' => $volvicBrand->id,
                'sku' => 'VOLVIC-1000',
                'barcode' => '3057640100412',
                'price' => 1.90,
                'cost_price' => 1.10,
                'pack_size' => 12,
                'pack_unit' => 'carton',
                'image_url' => 'https://images.unsplash.com/photo-1605518216938-7c31b7b14ad0?w=300&q=80',
            ],
            [
                'name' => 'Perrier Sparkling Water 330ml',
                'category_id' => $waterCategory->id,
                'brand_id' => $perrierBrand->id,
                'sku' => 'PERRIER-330',
                'barcode' => '3081140001083',
                'price' => 1.25,
                'cost_price' => 0.75,
                'pack_size' => 24,
                'pack_unit' => 'tray',
                'image_url' => 'https://images.unsplash.com/photo-1523362628745-0c100150b504?w=300&q=80',
            ],
        ];

        $products = [];
        foreach ($productsData as $pData) {
            $products[] = \App\Models\Product::firstOrCreate(
                ['company_id' => $company->id, 'sku' => $pData['sku']],
                array_merge($pData, [
                    'id' => (string) Str::ulid(),
                    'is_active' => true,
                ])
            );
        }

        // ── 9. Seed Warehouse & Inventory ───────────────────────────
        $warehouse = \App\Models\Warehouse::firstOrCreate(
            ['company_id' => $company->id, 'name' => 'Paris Central Warehouse'],
            [
                'id' => (string) Str::ulid(),
                'location' => '10 Rue de la Logistique, Paris (48.8566, 2.3522)',
                'is_active' => true,
            ]
        );

        foreach ($products as $product) {
            \App\Models\Inventory::firstOrCreate(
                ['product_id' => $product->id, 'warehouse_id' => $warehouse->id],
                [
                    'id' => (string) Str::ulid(),
                    'company_id' => $company->id,
                    'quantity' => 500,
                    'min_stock' => 20,
                    'max_stock' => 2000,
                ]
            );
        }

        // ── 10. Seed Promotion Rules ────────────────────────────────
        \App\Models\PromotionRule::firstOrCreate(
            ['company_id' => $company->id, 'name' => '10% Off Beverages'],
            [
                'id' => (string) Str::ulid(),
                'type' => 'percentage',
                'is_active' => true,
                'configuration' => [
                    'percentage' => 10,
                    'product_ids' => [$products[0]->id, $products[2]->id],
                ],
                'priority' => 10,
            ]
        );

        \App\Models\PromotionRule::firstOrCreate(
            ['company_id' => $company->id, 'name' => 'Bulk Lays Discount'],
            [
                'id' => (string) Str::ulid(),
                'type' => 'bulk_tier',
                'is_active' => true,
                'configuration' => [
                    'product_id' => $products[1]->id,
                    'tiers' => [
                        ['min_quantity' => 10, 'unit_price' => 2.20],
                        ['min_quantity' => 20, 'unit_price' => 2.00],
                    ],
                ],
                'priority' => 5,
            ]
        );

        $this->command->info('✅ Database seeded successfully!');
    }
}
