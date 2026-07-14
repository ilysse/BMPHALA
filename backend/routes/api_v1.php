<?php

use Illuminate\Support\Facades\Route;
use Illuminate\Support\Facades\Storage;
use App\Http\Controllers\Api\V1\AuthController;
use App\Http\Controllers\Api\V1\UserController;
use App\Http\Controllers\Api\V1\ProductController;
use App\Http\Controllers\Api\V1\CategoryController;
use App\Http\Controllers\Api\V1\BrandController;
use App\Http\Controllers\Api\V1\WarehouseController;
use App\Http\Controllers\Api\V1\InventoryController;
use App\Http\Controllers\Api\V1\OrderController;
use App\Http\Controllers\Api\V1\ReportController;
use App\Http\Controllers\Api\V1\PaymentController;
use App\Http\Controllers\Api\V1\PromotionController;
use App\Http\Controllers\Api\V1\NotificationController;
use App\Http\Controllers\Api\V1\FeatureFlagController;
use App\Http\Controllers\Api\V1\AuditLogController;
use App\Http\Controllers\Api\V1\UploadController;
use App\Http\Controllers\Api\V1\DispatchController;
use App\Http\Controllers\Api\V1\SmsGatewayController;
use App\Http\Controllers\Api\V1\CatalogBulkController;
use App\Http\Controllers\Api\V1\SupplierController;
use App\Http\Controllers\Api\V1\PurchaseOrderController;
use App\Http\Controllers\Api\V1\WhatsAppWebhookController;
use App\Http\Controllers\Api\V1\DeploymentController;
use App\Http\Controllers\Api\V1\NotificationTemplateController;
use App\Http\Controllers\Api\V1\CompanyController;
use App\Http\Controllers\Api\V1\DeviceTokenController;

/*
|--------------------------------------------------------------------------
| API Routes - V1
|--------------------------------------------------------------------------
*/

Route::get('/images', function (Illuminate\Http\Request $request) {
    $path = ltrim(str_replace('\\', '/', (string) $request->query('path')), '/');
    $path = preg_replace('#^storage/#', '', $path) ?? '';

    abort_if($path === '' || str_contains($path, '..') || str_contains($path, "\0"), 400, 'Invalid path');
    abort_unless(Storage::disk('public')->exists($path), 404);

    return Storage::disk('public')->response($path, null, [
        'Access-Control-Allow-Origin' => '*',
        'Cache-Control' => 'public, max-age=86400',
    ]);
});

// Public Auth Routes
Route::post('/auth/login', [AuthController::class, 'login']);
Route::post('/auth/mobile-login', [AuthController::class, 'login']);
Route::post('/auth/register', [AuthController::class, 'register']);
Route::post('/auth/refresh', [AuthController::class, 'refresh']);
Route::post('/auth/otp/request', [AuthController::class, 'requestOtp']);
Route::post('/auth/otp/verify', [AuthController::class, 'verifyOtp']);
Route::get('/sms-gateway/messages/next', [SmsGatewayController::class, 'next']);
Route::post('/sms-gateway/messages/{id}/status', [SmsGatewayController::class, 'status']);
Route::get('/whatsapp/webhook', [WhatsAppWebhookController::class, 'verify']);
Route::post('/whatsapp/webhook', [WhatsAppWebhookController::class, 'receive']);
Route::post('/deploy/migrate', [DeploymentController::class, 'migrate']);

// Protected Routes
Route::middleware('jwt.auth')->group(function () {
    // Auth Profile & Logout
    Route::get('/auth/me', [AuthController::class, 'me']);
    Route::post('/auth/logout', [AuthController::class, 'logout']);
    Route::post('/devices/token', [DeviceTokenController::class, 'store']);
    Route::delete('/devices/token', [DeviceTokenController::class, 'destroy']);

    // Company Settings
    Route::get('/company', [CompanyController::class, 'show']);
    Route::put('/company', [CompanyController::class, 'update']);

      // User Management
      Route::get('/users/registrations/pending', [UserController::class, 'pendingRegistrations']);
      Route::put('/users/{id}/password', [UserController::class, 'updatePassword']);
      Route::put('/users/{id}/approve', [UserController::class, 'approve']);
      Route::put('/users/{id}/reject', [UserController::class, 'reject']);
      Route::put('/users/{id}/cash-collection', [UserController::class, 'updateCashCollection']);
      Route::put('/users/{id}/representative-features', [UserController::class, 'updateRepresentativeFeatures']);
      Route::apiResource('users', UserController::class);

    // Uploads
    Route::post('/upload', [UploadController::class, 'store']);

    // Product Catalog
    Route::apiResource('products', ProductController::class);
    Route::apiResource('categories', CategoryController::class);
    Route::apiResource('brands', BrandController::class);
    Route::get('/catalog/export', [CatalogBulkController::class, 'export']);
    Route::post('/catalog/import', [CatalogBulkController::class, 'import']);

    // Warehouses & Inventory
    Route::apiResource('warehouses', WarehouseController::class);
    Route::get('/inventory', [InventoryController::class, 'index']);
    Route::post('/inventory/adjust', [InventoryController::class, 'adjust']);

    // Procurement
    Route::apiResource('suppliers', SupplierController::class);
    Route::get('/purchase-orders/stats', [PurchaseOrderController::class, 'stats']);
    Route::post('/purchase-orders/{purchaseOrder}/receive', [PurchaseOrderController::class, 'receive']);
    Route::put('/purchase-orders/{purchaseOrder}/status', [PurchaseOrderController::class, 'updateStatus']);
    Route::apiResource('purchase-orders', PurchaseOrderController::class)
        ->only(['index', 'store', 'show'])
        ->parameters(['purchase-orders' => 'purchaseOrder']);

    // Order Management & Workflow
    Route::apiResource('orders', OrderController::class);
    Route::put('/orders/{order}/status', [OrderController::class, 'updateStatus']);
    Route::post('/orders/{order}/assign', [OrderController::class, 'assign']);
    Route::post('/orders/{order}/deliver', [OrderController::class, 'deliver']);
    Route::post('/orders/{order}/cancel', [OrderController::class, 'cancel']);

    // Map Dispatch
    Route::get('/dispatch/orders', [DispatchController::class, 'orders']);
    Route::post('/dispatch/preview', [DispatchController::class, 'preview']);
    Route::post('/dispatch/assign', [DispatchController::class, 'assign']);

    // Payments
    Route::get('/payments', [PaymentController::class, 'index']);
    Route::post('/payments', [PaymentController::class, 'store']);
    Route::get('/payments/summary/{customer}', [PaymentController::class, 'summary']);

    // Promotions Engine
    Route::post('/promotions/calculate', [PromotionController::class, 'calculate']);
    Route::apiResource('promotions', PromotionController::class);

    // Notifications
    Route::get('/notifications', [NotificationController::class, 'index']);
    Route::put('/notifications/{id}/read', [NotificationController::class, 'markRead']);
    Route::put('/notifications/read-all', [NotificationController::class, 'markAllRead']);

    // Notification Templates
    Route::apiResource('notification-templates', NotificationTemplateController::class);

    // Feature Flags
    Route::get('/features', [FeatureFlagController::class, 'index']);
    Route::put('/features/{key}', [FeatureFlagController::class, 'update']);
    Route::put('/features/{key}/toggle', [FeatureFlagController::class, 'toggle']);

    // Reports
    Route::get('/reports/sales', [ReportController::class, 'sales']);

    // Invoices
    Route::get('/invoices', [\App\Http\Controllers\Api\V1\InvoiceController::class, 'index']);
    Route::post('/invoices', [\App\Http\Controllers\Api\V1\InvoiceController::class, 'generate']);
    Route::get('/invoices/{id}', [\App\Http\Controllers\Api\V1\InvoiceController::class, 'show']);
    Route::put('/invoices/{id}/status', [\App\Http\Controllers\Api\V1\InvoiceController::class, 'updateStatus']);

    // Audit Logs
    Route::get('/audit-logs', [AuditLogController::class, 'index']);
});
