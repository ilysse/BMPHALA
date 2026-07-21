<?php

namespace Tests\Feature;

use App\Models\Brand;
use App\Models\Category;
use App\Models\Company;
use App\Models\Inventory;
use App\Models\Notification;
use App\Models\Order;
use App\Models\OtpChallenge;
use App\Models\OutboundMessage;
use App\Models\Product;
use App\Models\PromotionRule;
use App\Models\User;
use App\Models\Warehouse;
use App\Services\JwtAuthService;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Hash;
use Carbon\Carbon;
use Tests\TestCase;

class BmpTest extends TestCase
{
    use RefreshDatabase;

    protected JwtAuthService $jwtService;
    protected Company $companyA;
    protected Company $companyB;
    protected User $adminA;
    protected User $retailerA;
    protected User $distributorA;
    protected User $adminB;

    protected function setUp(): void
    {
        parent::setUp();

        $this->jwtService = $this->app->make(JwtAuthService::class);

        $this->companyA = Company::create(['name' => 'Company A', 'status' => 'active']);
        $this->companyB = Company::create(['name' => 'Company B', 'status' => 'active']);

        $this->adminA = $this->createUser($this->companyA, 'admin@companya.com', 'admin');
        $this->retailerA = $this->createUser($this->companyA, 'retailer@companya.com', 'retailer');
        $this->distributorA = $this->createUser($this->companyA, 'distributor@companya.com', 'distributor');
        $this->adminB = $this->createUser($this->companyB, 'admin@companyb.com', 'admin');

        config(['services.registration.company_id' => $this->companyA->id]);
    }

    private function createUser(Company $company, string $email, string $role): User
    {
        return User::create([
            'company_id' => $company->id,
            'name' => ucfirst($role) . ' User',
            'email' => $email,
            'password' => Hash::make('password'),
            'role' => $role,
            'status' => 'active',
        ]);
    }

    private function authHeader(User $user): array
    {
        $token = $this->jwtService->encode([
            'sub' => $user->id,
            'type' => 'access',
            'role' => $user->role,
            'company_id' => $user->company_id,
        ]);

        return ['Authorization' => "Bearer {$token}"];
    }

    private function createCatalog(Company $company, string $sku = 'SKU-001', float $price = 3.00): array
    {
        $category = Category::create([
            'company_id' => $company->id,
            'name' => 'Beverages',
            'slug' => 'beverages-' . strtolower($sku),
        ]);

        $brand = Brand::create([
            'company_id' => $company->id,
            'name' => 'Generic',
            'slug' => 'generic-' . strtolower($sku),
        ]);

        $product = Product::create([
            'company_id' => $company->id,
            'category_id' => $category->id,
            'brand_id' => $brand->id,
            'name' => 'Energy Drink',
            'sku' => $sku,
            'image_url' => 'uploads/' . strtolower($sku) . '.webp',
            'price' => $price,
            'cost_price' => 1.00,
            'pack_size' => 12,
            'pack_unit' => 'box',
        ]);

        $warehouse = Warehouse::create([
            'company_id' => $company->id,
            'name' => 'Main Warehouse',
            'location' => 'Test Location',
        ]);

        $inventory = Inventory::create([
            'company_id' => $company->id,
            'product_id' => $product->id,
            'warehouse_id' => $warehouse->id,
            'quantity' => 100,
            'min_stock' => 10,
            'max_stock' => 1000,
        ]);

        return compact('category', 'brand', 'product', 'warehouse', 'inventory');
    }

    public function test_it_authenticates_a_user_and_returns_jwt(): void
    {
        $response = $this->postJson('/api/v1/auth/login', [
            'email' => 'admin@companya.com',
            'password' => 'password',
        ]);

        $response->assertOk()
            ->assertJsonPath('success', true)
            ->assertJsonStructure([
                'data' => [
                    'access_token',
                    'refresh_token',
                    'token_type',
                    'user' => ['id', 'name', 'email', 'role'],
                ],
            ]);
    }

    public function test_phone_otp_login_queues_sms_and_returns_jwt_once(): void
    {
        $this->retailerA->forceFill([
            'metadata' => ['phone' => '+212612345678'],
        ])->save();

        $request = $this->postJson('/api/v1/auth/otp/request', [
            'phone' => '0612345678',
            'channel' => 'sms',
        ]);

        $request->assertOk()
            ->assertJsonPath('success', true)
            ->assertJsonPath('data.channel', 'sms');

        $challenge = OtpChallenge::latest()->first();
        $this->assertNotNull($challenge);
        $this->assertSame('+212612345678', $challenge->normalized_phone);
        $this->assertDatabaseHas('outbound_messages', [
            'channel' => 'sms',
            'to_phone' => '+212612345678',
            'status' => 'pending',
            'provider' => 'database_gateway',
        ]);

        $verify = $this->postJson('/api/v1/auth/otp/verify', [
            'phone' => '+212 612 345 678',
            'channel' => 'sms',
            'code' => $challenge->metadata['test_code'],
        ]);

        $verify->assertOk()
            ->assertJsonPath('success', true)
            ->assertJsonPath('data.user.id', $this->retailerA->id)
            ->assertJsonStructure(['data' => ['access_token', 'refresh_token']]);

        $this->postJson('/api/v1/auth/otp/verify', [
            'phone' => '+212612345678',
            'channel' => 'sms',
            'code' => $challenge->metadata['test_code'],
        ])->assertUnprocessable();
    }

    public function test_admin_can_disable_and_enable_company_otp_login(): void
    {
        $this->retailerA->forceFill([
            'metadata' => ['phone' => '+212612345678'],
        ])->save();

        $this->getJson('/api/v1/auth/config')
            ->assertOk()
            ->assertJsonPath('data.otp_login_enabled', true);

        $this->postJson('/api/v1/auth/otp/request', [
            'phone' => '0612345678',
            'channel' => 'sms',
        ])->assertOk();
        $challenge = OtpChallenge::latest()->firstOrFail();

        $this->putJson('/api/v1/features/otp_login', [
            'is_enabled' => false,
        ], $this->authHeader($this->adminA))
            ->assertOk()
            ->assertJsonPath('data.is_enabled', false);

        $this->getJson('/api/v1/auth/config')
            ->assertOk()
            ->assertJsonPath('data.otp_login_enabled', false);

        $this->postJson('/api/v1/auth/otp/request', [
            'phone' => '0612345678',
            'channel' => 'sms',
        ])->assertUnprocessable()
            ->assertJsonPath('message', 'OTP login is disabled for this company.');

        $this->postJson('/api/v1/auth/otp/verify', [
            'phone' => '0612345678',
            'channel' => 'sms',
            'code' => $challenge->metadata['test_code'],
        ])->assertUnprocessable()
            ->assertJsonPath('message', 'OTP login is disabled for this company.');

        $this->putJson('/api/v1/features/otp_login', [
            'is_enabled' => true,
        ], $this->authHeader($this->retailerA))->assertForbidden();

        $this->putJson('/api/v1/features/otp_login', [
            'is_enabled' => true,
        ], $this->authHeader($this->adminA))->assertOk();

        $this->postJson('/api/v1/auth/otp/request', [
            'phone' => '0612345678',
            'channel' => 'sms',
        ])->assertOk();

        $this->getJson('/api/v1/auth/config')
            ->assertOk()
            ->assertJsonPath('data.otp_login_enabled', true);
    }

    public function test_registration_rejects_a_phone_already_linked_to_an_account(): void
    {
        $salesRep = $this->createUser($this->companyA, 'phone-rep@companya.com', 'sales_rep');
        $salesRep->forceFill(['metadata' => ['referral_code' => 'REP-PHONE']])->save();
        $this->retailerA->forceFill(['metadata' => ['phone' => '+212612345678']])->save();

        $this->postJson('/api/v1/auth/register', [
            'name' => 'Duplicate Phone Shop',
            'email' => 'duplicate-phone@example.com',
            'password' => 'password',
            'password_confirmation' => 'password',
            'phone' => '0612345678',
            'referral_code' => 'REP-PHONE',
            'latitude' => 33.5731,
            'longitude' => -7.5898,
            'address' => 'Casablanca',
        ])->assertUnprocessable()
            ->assertJsonValidationErrors('phone');
    }

    public function test_otp_wrong_attempts_unknown_phone_and_whatsapp_fallback_are_safe(): void
    {
        $this->retailerA->forceFill([
            'metadata' => ['phone' => '+33687654321'],
        ])->save();

        $this->postJson('/api/v1/auth/otp/request', [
            'phone' => '+33687654321',
            'channel' => 'whatsapp',
        ])->assertOk()
            ->assertJsonPath('success', true);

        $challenge = OtpChallenge::latest()->first();
        $this->postJson('/api/v1/auth/otp/verify', [
            'phone' => '+33687654321',
            'channel' => 'whatsapp',
            'code' => '000000',
        ])->assertUnprocessable()
            ->assertJsonPath('success', false);

        $this->assertSame(1, $challenge->fresh()->attempts);
        $this->assertDatabaseHas('outbound_messages', [
            'channel' => 'whatsapp',
            'to_phone' => '+33687654321',
            'provider' => 'database_gateway',
        ]);

        $unknown = $this->postJson('/api/v1/auth/otp/request', [
            'phone' => '+33600000000',
            'channel' => 'sms',
        ]);

        $unknown->assertOk()
            ->assertJsonPath('success', true)
            ->assertJsonPath('data', null);
    }

    public function test_sms_gateway_requires_token_and_records_status(): void
    {
        $message = OutboundMessage::create([
            'channel' => 'sms',
            'to_phone' => '+212612345678',
            'body' => 'Your BMP login code is 123456.',
            'status' => 'pending',
            'provider' => 'database_gateway',
            'available_at' => now(),
        ]);

        $this->getJson('/api/v1/sms-gateway/messages/next')
            ->assertUnauthorized();

        $next = $this->getJson('/api/v1/sms-gateway/messages/next', [
            'X-Gateway-Token' => 'local-dev-token',
        ]);

        $next->assertOk()
            ->assertJsonPath('data.id', $message->id)
            ->assertJsonPath('data.to_phone', '+212612345678');

        $this->postJson("/api/v1/sms-gateway/messages/{$message->id}/status", [
            'status' => 'delivered',
            'provider_reference' => 'phone-1',
        ], [
            'X-Gateway-Token' => 'local-dev-token',
        ])->assertOk()
            ->assertJsonPath('data.status', 'delivered');

        $this->assertNotNull($message->fresh()->delivered_at);
    }

    public function test_sms_gateway_phone_page_is_available(): void
    {
        $this->get('/sms-gateway')
            ->assertOk()
            ->assertSee('BMP SMS Gateway')
            ->assertSee('X-Gateway-Token');
    }

    public function test_retailer_registration_persists_location_fields(): void
    {
        $this->adminA->forceFill([
            'role' => 'sales_rep',
            'metadata' => ['referral_code' => 'REP-TEST'],
        ])->save();

        $response = $this->postJson('/api/v1/auth/register', [
            'name' => 'Mapped Retailer',
            'email' => 'mapped-retailer@example.com',
            'password' => 'password',
            'password_confirmation' => 'password',
            'phone' => '+212611223344',
            'referral_code' => 'REP-TEST',
            'latitude' => 48.8566,
            'longitude' => 2.3522,
            'address' => 'Paris Center',
        ]);

        $response->assertCreated()
            ->assertJsonPath('success', true)
            ->assertJsonPath('data.approval_required', true)
            ->assertJsonPath('data.user.role', 'retailer')
            ->assertJsonPath('data.user.status', 'pending')
            ->assertJsonPath('data.user.latitude', '48.8566000')
            ->assertJsonPath('data.user.longitude', '2.3522000')
            ->assertJsonPath('data.user.address', 'Paris Center');

        $this->assertDatabaseHas('users', [
            'email' => 'mapped-retailer@example.com',
            'company_id' => $this->companyA->id,
            'address' => 'Paris Center',
        ]);

        $this->postJson('/api/v1/auth/register', [
            'name' => 'Unmapped Retailer',
            'email' => 'unmapped-retailer@example.com',
            'password' => 'password',
            'password_confirmation' => 'password',
        ])->assertUnprocessable()
            ->assertJsonValidationErrors(['address', 'latitude', 'longitude']);
    }

    public function test_registered_retailer_requires_admin_approval_before_login(): void
    {
        $salesRep = $this->createUser($this->companyA, 'approval-rep@companya.com', 'sales_rep');
        $salesRep->forceFill([
            'metadata' => ['referral_code' => 'REP-APPROVAL'],
        ])->save();

        $registration = $this->postJson('/api/v1/auth/register', [
            'name' => 'Pending Approval Shop',
            'email' => 'pending-approval@example.com',
            'password' => 'password',
            'password_confirmation' => 'password',
            'phone' => '+212611223399',
            'referral_code' => 'REP-APPROVAL',
            'latitude' => 33.5731,
            'longitude' => -7.5898,
            'address' => 'Casablanca',
        ]);

        $registration->assertCreated()
            ->assertJsonPath('success', true)
            ->assertJsonPath('data.approval_required', true)
            ->assertJsonPath('data.user.status', 'pending')
            ->assertJsonMissingPath('data.access_token');

        $userId = $registration->json('data.user.id');

        $this->postJson('/api/v1/auth/login', [
            'email' => 'pending-approval@example.com',
            'password' => 'password',
        ])->assertForbidden()
            ->assertJsonPath('message', 'Your account is waiting for administrator approval.');

        $this->putJson("/api/v1/users/{$userId}/approve", [], $this->authHeader($this->retailerA))
            ->assertForbidden();

        $this->putJson("/api/v1/users/{$userId}/approve", [], $this->authHeader($this->adminB))
            ->assertNotFound();

        $this->putJson("/api/v1/users/{$userId}/approve", [], $this->authHeader($this->adminA))
            ->assertOk()
            ->assertJsonPath('data.status', 'active');

        $this->assertDatabaseHas('audit_logs', [
            'company_id' => $this->companyA->id,
            'user_id' => $this->adminA->id,
            'event' => 'user.approved',
            'auditable_id' => $userId,
        ]);

        $this->postJson('/api/v1/auth/login', [
            'email' => 'pending-approval@example.com',
            'password' => 'password',
        ])->assertOk()
            ->assertJsonPath('data.user.status', 'active')
            ->assertJsonStructure(['data' => ['access_token', 'refresh_token']]);
    }

    public function test_admin_can_list_and_reject_pending_registrations(): void
    {
        $pendingA = $this->createUser($this->companyA, 'pending-a@example.com', 'retailer');
        $pendingA->forceFill([
            'name' => 'Pending Shop A',
            'status' => 'pending',
            'metadata' => ['phone' => '+212611111111'],
            'latitude' => 33.5731,
            'longitude' => -7.5898,
            'address' => 'Casablanca Center',
        ])->save();

        $pendingB = $this->createUser($this->companyB, 'pending-b@example.com', 'retailer');
        $pendingB->forceFill(['status' => 'pending'])->save();

        $this->getJson('/api/v1/users/registrations/pending', $this->authHeader($this->retailerA))
            ->assertForbidden();

        $this->getJson('/api/v1/users/registrations/pending?search=Pending%20Shop', $this->authHeader($this->adminA))
            ->assertOk()
            ->assertJsonPath('meta.total', 1)
            ->assertJsonPath('data.0.id', $pendingA->id)
            ->assertJsonPath('data.0.status', 'pending')
            ->assertJsonPath('data.0.latitude', '33.5731000')
            ->assertJsonPath('data.0.longitude', '-7.5898000')
            ->assertJsonPath('data.0.address', 'Casablanca Center')
            ->assertJsonMissing(['id' => $pendingB->id]);

        $this->putJson("/api/v1/users/{$pendingA->id}/reject", [
            'reason' => 'Shop information could not be verified.',
        ], $this->authHeader($this->adminB))->assertNotFound();

        $this->putJson("/api/v1/users/{$pendingA->id}/reject", [
            'reason' => 'Shop information could not be verified.',
        ], $this->authHeader($this->adminA))
            ->assertOk()
            ->assertJsonPath('data.status', 'inactive');

        $this->assertDatabaseHas('audit_logs', [
            'company_id' => $this->companyA->id,
            'user_id' => $this->adminA->id,
            'event' => 'user.rejected',
            'auditable_id' => $pendingA->id,
        ]);

        $this->getJson('/api/v1/users/registrations/pending', $this->authHeader($this->adminA))
            ->assertOk()
            ->assertJsonPath('meta.total', 0);
    }

    public function test_registration_accepts_email_phone_or_both(): void
    {
        $emailOnly = $this->postJson('/api/v1/auth/register', [
            'name' => 'Email Only Owner',
            'company_name' => 'Email Only Shop',
            'email' => 'email-only@example.com',
            'password' => 'password',
            'password_confirmation' => 'password',
            'latitude' => 33.5731,
            'longitude' => -7.5898,
            'address' => 'Casablanca Email Shop',
        ]);

        $emailOnly->assertCreated()
            ->assertJsonPath('data.user.email', 'email-only@example.com')
            ->assertJsonPath('data.user.phone', null)
            ->assertJsonPath('data.user.role', 'retailer')
            ->assertJsonPath('data.user.status', 'pending')
            ->assertJsonPath('data.user.company_id', $this->companyA->id)
            ->assertJsonPath('data.approval_required', true)
            ->assertJsonMissingPath('data.access_token');

        $phoneOnly = $this->postJson('/api/v1/auth/register', [
            'name' => 'Phone Only Owner',
            'company_name' => 'Phone Only Shop',
            'phone' => '0651463220',
            'password' => 'password',
            'password_confirmation' => 'password',
            'latitude' => 34.0209,
            'longitude' => -6.8416,
            'address' => 'Rabat Phone Shop',
        ]);

        $phoneOnly->assertCreated()
            ->assertJsonPath('data.user.email', null)
            ->assertJsonPath('data.user.phone', '0651463220')
            ->assertJsonPath('data.user.role', 'retailer')
            ->assertJsonPath('data.user.status', 'pending')
            ->assertJsonPath('data.user.company_id', $this->companyA->id)
            ->assertJsonPath('data.approval_required', true);

        $this->postJson('/api/v1/auth/login', [
            'identifier' => '0651463220',
            'password' => 'password',
        ])->assertForbidden()
            ->assertJsonPath('message', 'Your account is waiting for administrator approval.');

        $this->putJson(
            "/api/v1/users/{$phoneOnly->json('data.user.id')}/approve",
            [],
            $this->authHeader($this->adminA)
        )->assertOk();

        $this->postJson('/api/v1/auth/login', [
            'identifier' => '0651463220',
            'password' => 'password',
        ])->assertOk()
            ->assertJsonPath('data.user.phone', '0651463220');

        $both = $this->postJson('/api/v1/auth/register', [
            'name' => 'Both Contacts Owner',
            'company_name' => 'Both Contacts Shop',
            'email' => 'both-contacts@example.com',
            'phone' => '+212612345699',
            'password' => 'password',
            'password_confirmation' => 'password',
            'latitude' => 35.7595,
            'longitude' => -5.8340,
            'address' => 'Tangier Shop',
        ]);

        $both->assertCreated()
            ->assertJsonPath('data.user.email', 'both-contacts@example.com')
            ->assertJsonPath('data.user.phone', '+212612345699')
            ->assertJsonPath('data.user.status', 'pending');

        $this->postJson('/api/v1/auth/register', [
            'name' => 'Missing Contacts Owner',
            'company_name' => 'Missing Contacts Shop',
            'password' => 'password',
            'password_confirmation' => 'password',
        ])->assertUnprocessable()
            ->assertJsonValidationErrors(['email', 'phone']);

        $this->assertSame(2, Company::withoutGlobalScopes()->count());
    }

    public function test_it_enforces_multi_tenancy_isolation_for_products(): void
    {
        $catalogA = $this->createCatalog($this->companyA, 'COKE-A', 1.50);
        $catalogB = $this->createCatalog($this->companyB, 'LAYS-B', 2.50);

        $responseA = $this->getJson('/api/v1/products', $this->authHeader($this->adminA));
        $responseA->assertOk()
            ->assertJsonCount(1, 'data')
            ->assertJsonPath('data.0.id', $catalogA['product']->id)
            ->assertJsonPath('data.0.sku', 'COKE-A');

        $responseB = $this->getJson('/api/v1/products', $this->authHeader($this->adminB));
        $responseB->assertOk()
            ->assertJsonCount(1, 'data')
            ->assertJsonPath('data.0.id', $catalogB['product']->id)
            ->assertJsonPath('data.0.sku', 'LAYS-B');
    }

    public function test_admin_can_create_a_product_with_ulid_relationships(): void
    {
        $catalog = $this->createCatalog($this->companyA, 'SEED-001', 1.00);

        $response = $this->postJson('/api/v1/products', [
            'name' => 'Sparkling Water',
            'sku' => 'WATER-001',
            'price' => 2.25,
            'cost_price' => 1.10,
            'pack_size' => 24,
            'pack_unit' => 'tray',
            'category_id' => $catalog['category']->id,
            'brand_id' => $catalog['brand']->id,
            'image_url' => 'uploads/water-001.webp',
        ], $this->authHeader($this->adminA));

        $response->assertCreated()
            ->assertJsonPath('success', true)
            ->assertJsonPath('data.sku', 'WATER-001')
            ->assertJsonPath('data.price', '2.25')
            ->assertJsonPath(
                'data.image_url',
                url('api/v1/images?path=' . urlencode('uploads/water-001.webp'))
            );
    }

    public function test_admin_can_update_and_delete_live_product_records(): void
    {
        $catalog = $this->createCatalog($this->companyA, 'LIVE-PROD-001', 10.00);
        $product = $catalog['product'];

        $update = $this->putJson("/api/v1/products/{$product->id}", [
            'name' => 'Live Managed Product',
            'sku' => 'LIVE-PROD-UPDATED',
            'price' => 25.50,
            'cost_price' => 12.25,
            'pack_size' => 6,
            'pack_unit' => 'box',
            'category_id' => $catalog['category']->id,
            'brand_id' => $catalog['brand']->id,
            'description' => 'Managed from admin product screen.',
            'is_active' => false,
        ], $this->authHeader($this->adminA));

        $update->assertOk()
            ->assertJsonPath('success', true)
            ->assertJsonPath('data.name', 'Live Managed Product')
            ->assertJsonPath('data.price', '25.50')
            ->assertJsonPath('data.is_active', false);

        $delete = $this->deleteJson("/api/v1/products/{$product->id}", [], $this->authHeader($this->adminA));

        $delete->assertOk()
            ->assertJsonPath('success', true);

        $this->assertDatabaseMissing('products', [
            'id' => $product->id,
        ]);
    }

    public function test_it_calculates_promotions_correctly(): void
    {
        $catalog = $this->createCatalog($this->companyA, 'ENERGY', 3.00);

        PromotionRule::create([
            'company_id' => $this->companyA->id,
            'name' => '10% Off Energy',
            'type' => 'percentage',
            'is_active' => true,
            'configuration' => [
                'percentage' => 10,
                'product_ids' => [$catalog['product']->id],
            ],
            'priority' => 1,
        ]);

        $response = $this->postJson('/api/v1/promotions/calculate', [
            'items' => [
                ['product_id' => $catalog['product']->id, 'quantity' => 2],
            ],
        ], $this->authHeader($this->retailerA));

        $response->assertOk()
            ->assertJsonPath('success', true)
            ->assertJsonPath('data.total_amount', 6)
            ->assertJsonPath('data.total_discount', 0.6)
            ->assertJsonPath('data.grand_total', 5.4);
    }

    public function test_orders_after_six_pm_are_scheduled_two_days_ahead(): void
    {
        Carbon::setTestNow(Carbon::parse('2026-07-10 18:01:00', 'Africa/Casablanca'));

        try {
            $catalog = $this->createCatalog($this->companyA, 'CUTOFF-001', 5.00);

            $response = $this->postJson('/api/v1/orders', [
                'items' => [
                    ['product_id' => $catalog['product']->id, 'quantity' => 1],
                ],
                'delivery_address' => 'Cutoff Test Street',
            ], $this->authHeader($this->retailerA));

            $response->assertCreated();
            $scheduled = Carbon::parse($response->json('data.expected_delivery_at'))
                ->setTimezone('Africa/Casablanca');

            $this->assertSame('2026-07-12', $scheduled->toDateString());
            $this->assertSame(9, $scheduled->hour);
        } finally {
            Carbon::setTestNow();
        }
    }

    public function test_admin_can_update_company_invoice_profile(): void
    {
        $this->getJson('/api/v1/company', $this->authHeader($this->adminA))
            ->assertOk()
            ->assertJsonPath('data.id', $this->companyA->id);

        $this->putJson('/api/v1/company', [
            'name' => 'Company A Distribution',
            'email' => 'billing@companya.test',
            'phone' => '+212600000001',
            'tax_id' => 'ICE-123456',
            'address' => 'Casablanca, Morocco',
            'logo_url' => 'uploads/company-a-logo.jpg',
        ], $this->authHeader($this->adminA))
            ->assertOk()
            ->assertJsonPath('data.name', 'Company A Distribution')
            ->assertJsonPath('data.tax_id', 'ICE-123456');

        $this->putJson('/api/v1/company', [
            'name' => 'Forbidden Update',
        ], $this->authHeader($this->retailerA))->assertForbidden();

        $this->assertDatabaseHas('companies', [
            'id' => $this->companyA->id,
            'name' => 'Company A Distribution',
            'logo_url' => 'uploads/company-a-logo.jpg',
        ]);
    }

    public function test_retailer_can_place_order_and_enabled_collector_can_record_cash_payment(): void
    {
        $catalog = $this->createCatalog($this->companyA, 'ORDER-001', 4.00);
        $this->distributorA->forceFill([
            'metadata' => ['can_collect_cash' => true],
        ])->save();

        $orderResponse = $this->postJson('/api/v1/orders', [
            'items' => [
                ['product_id' => $catalog['product']->id, 'quantity' => 3],
            ],
            'delivery_address' => '123 Test Street',
        ], $this->authHeader($this->retailerA));

        $orderResponse->assertCreated()
            ->assertJsonPath('success', true)
            ->assertJsonPath('data.payment_status', 'unpaid')
            ->assertJsonPath('data.grand_total', '12.00');

        $orderId = $orderResponse->json('data.id');

        $this->postJson("/api/v1/orders/{$orderId}/assign", [
            'distributor_id' => $this->distributorA->id,
        ], $this->authHeader($this->adminA))->assertOk();

        $paymentResponse = $this->postJson('/api/v1/payments', [
            'order_id' => $orderId,
            'amount' => 12.00,
            'method' => 'cash',
            'reference_number' => 'CASH-001',
        ], $this->authHeader($this->distributorA));

        $paymentResponse->assertCreated()
            ->assertJsonPath('success', true)
            ->assertJsonPath('data.payment_method', 'cash')
            ->assertJsonPath('data.payment_status', 'completed');

        $this->assertDatabaseHas('orders', [
            'id' => $orderId,
            'payment_status' => 'paid',
        ]);

        $this->assertDatabaseHas('inventory', [
            'id' => $catalog['inventory']->id,
            'quantity' => 97,
        ]);
    }

    public function test_retailer_cannot_record_cash_payment_directly(): void
    {
        $catalog = $this->createCatalog($this->companyA, 'PAY-FORBID-001', 4.00);

        $orderId = $this->postJson('/api/v1/orders', [
            'items' => [
                ['product_id' => $catalog['product']->id, 'quantity' => 1],
            ],
            'delivery_address' => '123 Test Street',
        ], $this->authHeader($this->retailerA))->assertCreated()->json('data.id');

        $response = $this->postJson('/api/v1/payments', [
            'order_id' => $orderId,
            'amount' => 4.00,
            'method' => 'cash',
        ], $this->authHeader($this->retailerA));

        $response->assertForbidden()
            ->assertJsonPath('success', false);
    }

    public function test_sales_rep_can_collect_cash_only_for_responsible_retailers(): void
    {
        $catalog = $this->createCatalog($this->companyA, 'REP-CASH-001', 4.00);
        $salesRep = $this->createUser($this->companyA, 'rep@companya.com', 'sales_rep');
        $salesRep->forceFill([
            'metadata' => [
                'can_collect_cash' => true,
                'referral_code' => 'REP-CASH',
            ],
        ])->save();

        $this->retailerA->forceFill([
            'metadata' => ['responsible_id' => $salesRep->id],
        ])->save();

        $orderId = $this->postJson('/api/v1/orders', [
            'items' => [
                ['product_id' => $catalog['product']->id, 'quantity' => 2],
            ],
            'delivery_address' => 'Rep customer street',
        ], $this->authHeader($this->retailerA))->assertCreated()->json('data.id');

        $paymentResponse = $this->postJson('/api/v1/payments', [
            'order_id' => $orderId,
            'amount' => 4.00,
            'method' => 'cash',
            'reference_number' => 'REP-CASH-001',
        ], $this->authHeader($salesRep));

        $paymentResponse->assertCreated()
            ->assertJsonPath('success', true)
            ->assertJsonPath('data.payment_method', 'cash');

        $paymentIndex = $this->getJson('/api/v1/payments', $this->authHeader($salesRep));
        $paymentIndex->assertOk()
            ->assertJsonCount(1, 'data')
            ->assertJsonPath('data.0.order_id', $orderId);

        $otherRetailer = $this->createUser($this->companyA, 'other-retailer@companya.com', 'retailer');
        $otherOrder = Order::create([
            'company_id' => $this->companyA->id,
            'order_number' => 'OTHER-REP-CASH',
            'retailer_id' => $otherRetailer->id,
            'status' => 'confirmed',
            'payment_status' => 'unpaid',
            'total_amount' => 4,
            'grand_total' => 4,
        ]);

        $forbidden = $this->postJson('/api/v1/payments', [
            'order_id' => $otherOrder->id,
            'amount' => 4.00,
            'method' => 'cash',
        ], $this->authHeader($salesRep));

        $forbidden->assertForbidden();
    }

    public function test_non_cash_payment_methods_are_rejected(): void
    {
        $catalog = $this->createCatalog($this->companyA, 'PAY-CASH-ONLY-001', 4.00);
        $this->distributorA->forceFill([
            'metadata' => ['can_collect_cash' => true],
        ])->save();

        $orderId = $this->postJson('/api/v1/orders', [
            'items' => [
                ['product_id' => $catalog['product']->id, 'quantity' => 1],
            ],
            'delivery_address' => '123 Test Street',
        ], $this->authHeader($this->retailerA))->assertCreated()->json('data.id');

        $this->postJson("/api/v1/orders/{$orderId}/assign", [
            'distributor_id' => $this->distributorA->id,
        ], $this->authHeader($this->adminA))->assertOk();

        $response = $this->postJson('/api/v1/payments', [
            'order_id' => $orderId,
            'amount' => 4.00,
            'method' => 'mobile_money',
        ], $this->authHeader($this->distributorA));

        $response->assertUnprocessable()
            ->assertJsonValidationErrors('method');
    }

    public function test_cash_collector_permission_can_be_toggled_by_admin(): void
    {
        $response = $this->putJson("/api/v1/users/{$this->distributorA->id}/cash-collection", [
            'can_collect_cash' => true,
        ], $this->authHeader($this->adminA));

        $response->assertOk()
            ->assertJsonPath('data.can_collect_cash', true);

        $this->assertTrue((bool) $this->distributorA->fresh()->metadata['can_collect_cash']);
    }

    public function test_admin_can_reset_a_user_password_in_the_same_company(): void
    {
        $response = $this->putJson("/api/v1/users/{$this->retailerA->id}/password", [
            'password' => 'new-password-123',
            'password_confirmation' => 'new-password-123',
        ], $this->authHeader($this->adminA));

        $response->assertOk()
            ->assertJsonPath('success', true)
            ->assertJsonMissingPath('data.password');

        $this->assertTrue(Hash::check('new-password-123', $this->retailerA->fresh()->password));
        $this->assertDatabaseHas('audit_logs', [
            'company_id' => $this->companyA->id,
            'user_id' => $this->adminA->id,
            'event' => 'user.password_reset',
            'auditable_type' => User::class,
            'auditable_id' => $this->retailerA->id,
        ]);
    }

    public function test_non_admin_cannot_reset_passwords(): void
    {
        $this->putJson("/api/v1/users/{$this->distributorA->id}/password", [
            'password' => 'new-password-123',
            'password_confirmation' => 'new-password-123',
        ], $this->authHeader($this->retailerA))->assertForbidden();

        $this->assertTrue(Hash::check('password', $this->distributorA->fresh()->password));
    }

    public function test_admin_cannot_reset_a_user_password_in_another_company(): void
    {
        $this->putJson("/api/v1/users/{$this->adminB->id}/password", [
            'password' => 'new-password-123',
            'password_confirmation' => 'new-password-123',
        ], $this->authHeader($this->adminA))->assertNotFound();

        $this->assertTrue(Hash::check('password', $this->adminB->fresh()->password));
    }

    public function test_admin_can_see_counted_sales_and_toggle_representative_features(): void
    {
        $salesRep = $this->createUser($this->companyA, 'controlled-rep@companya.com', 'sales_rep');
        $salesRep->forceFill([
            'metadata' => ['referral_code' => 'REP-CONTROL'],
        ])->save();

        $this->retailerA->forceFill([
            'metadata' => ['responsible_id' => $salesRep->id],
        ])->save();

        Order::create([
            'company_id' => $this->companyA->id,
            'order_number' => 'REP-SALE-COUNTED',
            'retailer_id' => $this->retailerA->id,
            'status' => 'delivered',
            'payment_status' => 'paid',
            'total_amount' => 30,
            'grand_total' => 30,
        ]);

        Order::create([
            'company_id' => $this->companyA->id,
            'order_number' => 'REP-SALE-CANCELLED',
            'retailer_id' => $this->retailerA->id,
            'status' => 'cancelled',
            'payment_status' => 'unpaid',
            'total_amount' => 80,
            'grand_total' => 80,
        ]);

        $index = $this->getJson('/api/v1/users?role=sales_rep', $this->authHeader($this->adminA));

        $index->assertOk()
            ->assertJsonPath('data.0.id', $salesRep->id)
            ->assertJsonPath('data.0.sales_performance', 30)
            ->assertJsonPath('data.0.sales_order_count', 1)
            ->assertJsonPath('data.0.assigned_retailer_count', 1);

        $response = $this->putJson("/api/v1/users/{$salesRep->id}/representative-features", [
            'representative_features' => [
                'dashboard' => true,
                'retailers' => false,
                'orders' => true,
                'onboarding' => false,
            ],
        ], $this->authHeader($this->adminA));

        $response->assertOk()
            ->assertJsonPath('data.representative_features.dashboard', true)
            ->assertJsonPath('data.representative_features.retailers', false)
            ->assertJsonPath('data.representative_features.orders', true)
            ->assertJsonPath('data.representative_features.onboarding', false);

        $this->assertFalse((bool) $salesRep->fresh()->metadata['representative_features']['retailers']);
    }

    public function test_admin_can_assign_order_to_distributor_without_tenant_scope_recursion(): void
    {
        $catalog = $this->createCatalog($this->companyA, 'ASSIGN-001', 5.00);

        $orderResponse = $this->postJson('/api/v1/orders', [
            'items' => [
                ['product_id' => $catalog['product']->id, 'quantity' => 1],
            ],
            'delivery_address' => '123 Assignment Street',
        ], $this->authHeader($this->retailerA));

        $orderId = $orderResponse->assertCreated()->json('data.id');

        $assignResponse = $this->postJson("/api/v1/orders/{$orderId}/assign", [
            'distributor_id' => $this->distributorA->id,
        ], $this->authHeader($this->adminA));

        $assignResponse->assertOk()
            ->assertJsonPath('success', true)
            ->assertJsonPath('data.status', 'assigned')
            ->assertJsonPath('data.distributor.id', $this->distributorA->id);
    }

    public function test_retailer_order_snapshots_retailer_coordinates(): void
    {
        $this->retailerA->update([
            'latitude' => 48.8566000,
            'longitude' => 2.3522000,
            'address' => 'Paris Center',
        ]);
        $catalog = $this->createCatalog($this->companyA, 'GEO-001', 5.00);

        $response = $this->postJson('/api/v1/orders', [
            'items' => [
                ['product_id' => $catalog['product']->id, 'quantity' => 1],
            ],
            'delivery_address' => 'Paris Center',
        ], $this->authHeader($this->retailerA));

        $response->assertCreated()
            ->assertJsonPath('data.delivery_latitude', '48.8566000')
            ->assertJsonPath('data.delivery_longitude', '2.3522000');
    }

    public function test_admin_can_preview_and_dispatch_orders_inside_drawn_zone(): void
    {
        $this->retailerA->update([
            'latitude' => 48.8566000,
            'longitude' => 2.3522000,
            'address' => 'Paris Center',
        ]);
        $catalog = $this->createCatalog($this->companyA, 'MAP-001', 5.00);

        $insideResponse = $this->postJson('/api/v1/orders', [
            'items' => [
                ['product_id' => $catalog['product']->id, 'quantity' => 1],
            ],
            'delivery_address' => 'Paris Center',
        ], $this->authHeader($this->retailerA));
        $insideOrderId = $insideResponse->assertCreated()->json('data.id');

        Order::create([
            'company_id' => $this->companyA->id,
            'order_number' => 'OUTSIDE-ZONE',
            'retailer_id' => $this->retailerA->id,
            'status' => 'pending',
            'payment_status' => 'unpaid',
            'total_amount' => 10,
            'grand_total' => 10,
            'delivery_address' => 'Outside',
            'delivery_latitude' => 51.5074000,
            'delivery_longitude' => -0.1278000,
        ]);

        $zone = [
            'type' => 'Polygon',
            'coordinates' => [[
                [2.20, 48.80],
                [2.50, 48.80],
                [2.50, 48.95],
                [2.20, 48.95],
                [2.20, 48.80],
            ]],
        ];

        $preview = $this->postJson('/api/v1/dispatch/preview', [
            'zone_geojson' => $zone,
        ], $this->authHeader($this->adminA));

        $preview->assertOk()
            ->assertJsonPath('success', true)
            ->assertJsonPath('data.order_count', 1)
            ->assertJsonPath('data.orders.0.id', $insideOrderId);

        $assign = $this->postJson('/api/v1/dispatch/assign', [
            'zone_geojson' => $zone,
            'distributor_id' => $this->distributorA->id,
        ], $this->authHeader($this->adminA));

        $assign->assertCreated()
            ->assertJsonPath('success', true)
            ->assertJsonPath('data.assigned_count', 1);

        $this->assertDatabaseHas('orders', [
            'id' => $insideOrderId,
            'status' => 'assigned',
            'distributor_id' => $this->distributorA->id,
        ]);

        $this->assertDatabaseCount('dispatch_batches', 1);
        $this->assertDatabaseHas('dispatch_batch_order', [
            'order_id' => $insideOrderId,
        ]);
    }

    public function test_updating_retailer_location_backfills_undispatched_order_coordinates(): void
    {
        $catalog = $this->createCatalog($this->companyA, 'BACKFILL-001', 5.00);

        $orderResponse = $this->postJson('/api/v1/orders', [
            'items' => [
                ['product_id' => $catalog['product']->id, 'quantity' => 1],
            ],
            'delivery_address' => 'Missing map location',
        ], $this->authHeader($this->retailerA));
        $orderId = $orderResponse->assertCreated()->json('data.id');

        $this->assertDatabaseHas('orders', [
            'id' => $orderId,
            'delivery_latitude' => null,
            'delivery_longitude' => null,
        ]);

        $response = $this->putJson("/api/v1/users/{$this->retailerA->id}", [
            'latitude' => 48.8566,
            'longitude' => 2.3522,
            'address' => 'Paris Center',
        ], $this->authHeader($this->adminA));

        $response->assertOk()
            ->assertJsonPath('data.latitude', '48.8566000')
            ->assertJsonPath('data.longitude', '2.3522000');

        $this->assertDatabaseHas('orders', [
            'id' => $orderId,
            'delivery_latitude' => '48.8566000',
            'delivery_longitude' => '2.3522000',
            'delivery_address' => 'Paris Center',
        ]);
    }

    public function test_non_admin_cannot_use_dispatch_endpoints(): void
    {
        $response = $this->getJson('/api/v1/dispatch/orders', $this->authHeader($this->retailerA));

        $response->assertForbidden();
    }

    public function test_admin_can_adjust_inventory(): void
    {
        $catalog = $this->createCatalog($this->companyA, 'INV-001', 2.00);

        $response = $this->postJson('/api/v1/inventory/adjust', [
            'product_id' => $catalog['product']->id,
            'warehouse_id' => $catalog['warehouse']->id,
            'quantity' => -5,
            'notes' => 'Cycle count correction',
        ], $this->authHeader($this->adminA));

        $response->assertOk()
            ->assertJsonPath('success', true)
            ->assertJsonPath('data.quantity', 95);

        $this->assertDatabaseHas('stock_movements', [
            'product_id' => $catalog['product']->id,
            'warehouse_id' => $catalog['warehouse']->id,
            'type' => 'adjustment',
            'quantity' => -5,
            'user_id' => $this->adminA->id,
            'reason' => 'Cycle count correction',
        ]);
    }

    public function test_admin_can_manage_promotions_invoices_and_warehouses(): void
    {
        $catalog = $this->createCatalog($this->companyA, 'OPS-TOOLS-001', 6.00);

        $promotion = $this->postJson('/api/v1/promotions', [
            'name' => 'Ops Discount',
            'type' => 'percentage',
            'configuration' => ['percentage' => 5],
            'priority' => 3,
            'is_active' => true,
        ], $this->authHeader($this->adminA));

        $promotion->assertCreated()
            ->assertJsonPath('success', true)
            ->assertJsonPath('data.name', 'Ops Discount');

        $promotionId = $promotion->json('data.id');

        $this->putJson("/api/v1/promotions/{$promotionId}", [
            'name' => 'Ops Discount Updated',
            'type' => 'fixed',
            'configuration' => ['amount' => 2],
            'priority' => 4,
            'is_active' => false,
        ], $this->authHeader($this->adminA))
            ->assertOk()
            ->assertJsonPath('data.is_active', false);

        $orderId = $this->postJson('/api/v1/orders', [
            'items' => [
                ['product_id' => $catalog['product']->id, 'quantity' => 1],
            ],
            'delivery_address' => 'Invoice Street',
        ], $this->authHeader($this->retailerA))->assertCreated()->json('data.id');

        $invoice = $this->postJson('/api/v1/invoices', [
            'order_id' => $orderId,
            'due_date' => now()->addDays(7)->toDateString(),
        ], $this->authHeader($this->adminA));

        $invoice->assertCreated()
            ->assertJsonPath('success', true)
            ->assertJsonPath('data.status', 'draft');

        $invoiceId = $invoice->json('data.id');

        $this->putJson("/api/v1/invoices/{$invoiceId}/status", [
            'status' => 'sent',
        ], $this->authHeader($this->adminA))
            ->assertOk()
            ->assertJsonPath('data.status', 'sent');

        $warehouse = $this->postJson('/api/v1/warehouses', [
            'name' => 'Operations Warehouse',
            'location' => 'Ops District',
        ], $this->authHeader($this->adminA));

        $warehouse->assertCreated()
            ->assertJsonPath('data.name', 'Operations Warehouse');

        $warehouseId = $warehouse->json('data.id');

        $this->putJson("/api/v1/warehouses/{$warehouseId}", [
            'name' => 'Operations Warehouse Updated',
            'location' => 'Ops District 2',
            'is_active' => false,
        ], $this->authHeader($this->adminA))
            ->assertOk()
            ->assertJsonPath('data.is_active', false);

        $this->deleteJson("/api/v1/warehouses/{$warehouseId}", [], $this->authHeader($this->adminA))
            ->assertOk()
            ->assertJsonPath('success', true);
    }

    public function test_catalog_and_promotion_events_create_notifications(): void
    {
        $catalog = $this->createCatalog($this->companyA, 'NOTIFY-BASE-001', 4.00);

        $this->postJson('/api/v1/products', [
            'category_id' => $catalog['category']->id,
            'brand_id' => $catalog['brand']->id,
            'name' => 'Seasonal Juice',
            'sku' => 'NOTIFY-JUICE-001',
            'price' => 9.50,
            'cost_price' => 4.25,
            'pack_size' => 6,
            'pack_unit' => 'box',
            'is_active' => true,
        ], $this->authHeader($this->adminA))->assertCreated();

        $this->assertDatabaseHas('notifications', [
            'company_id' => $this->companyA->id,
            'user_id' => $this->retailerA->id,
            'type' => 'product_new',
            'title' => 'New product available',
        ]);

        $catalog['inventory']->update(['quantity' => 0]);

        $this->postJson('/api/v1/inventory/adjust', [
            'product_id' => $catalog['product']->id,
            'warehouse_id' => $catalog['warehouse']->id,
            'quantity' => 12,
            'notes' => 'Restock alert test',
        ], $this->authHeader($this->adminA))->assertOk();

        $this->assertDatabaseHas('notifications', [
            'company_id' => $this->companyA->id,
            'user_id' => $this->retailerA->id,
            'type' => 'product_restocked',
            'title' => 'Product restocked',
        ]);

        $this->postJson('/api/v1/promotions', [
            'name' => 'Notification Discount',
            'type' => 'percentage',
            'configuration' => ['percentage' => 10, 'product_ids' => [$catalog['product']->id]],
            'priority' => 5,
            'is_active' => true,
        ], $this->authHeader($this->adminA))->assertCreated();

        $this->assertDatabaseHas('notifications', [
            'company_id' => $this->companyA->id,
            'user_id' => $this->retailerA->id,
            'type' => 'promotion',
            'title' => 'New promotion',
        ]);

        $this->assertDatabaseMissing('notifications', [
            'company_id' => $this->companyB->id,
            'user_id' => $this->adminB->id,
            'type' => 'promotion',
        ]);

        $this->assertGreaterThanOrEqual(9, Notification::count());
    }

    public function test_whatsapp_webhook_verifies_and_records_inbound_messages(): void
    {
        config(['app.env' => 'testing']);
        putenv('WHATSAPP_WEBHOOK_VERIFY_TOKEN=test-webhook-token');
        $_ENV['WHATSAPP_WEBHOOK_VERIFY_TOKEN'] = 'test-webhook-token';

        $this->get('/api/v1/whatsapp/webhook?hub.mode=subscribe&hub.verify_token=test-webhook-token&hub.challenge=abc123')
            ->assertOk()
            ->assertSee('abc123');

        $this->postJson('/api/v1/whatsapp/webhook', [
            'entry' => [[
                'changes' => [[
                    'value' => [
                        'metadata' => ['phone_number_id' => '12345'],
                        'contacts' => [['wa_id' => '212612345678', 'profile' => ['name' => 'Retailer']]],
                        'messages' => [[
                            'id' => 'wamid.TEST',
                            'from' => '212612345678',
                            'type' => 'text',
                            'text' => ['body' => 'Hello Halawat'],
                        ]],
                    ],
                ]],
            ]],
        ])->assertOk()
            ->assertJsonPath('success', true);

        $this->assertDatabaseHas('outbound_messages', [
            'channel' => 'whatsapp',
            'to_phone' => '212612345678',
            'body' => 'Hello Halawat',
            'status' => 'received',
            'provider' => 'whatsapp_cloud',
            'provider_reference' => 'wamid.TEST',
        ]);

        $this->assertEquals(1, OutboundMessage::where('provider_reference', 'wamid.TEST')->count());
    }
}
