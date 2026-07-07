# Halawat Lil Moaamalat

Halawat Lil Moaamalat (`حلوات للمعاملات`) is a store ERP/CRM platform for wholesale and retail operations. It combines catalog management, inventory, orders, CRM, procurement, promotions, invoices, delivery dispatch, reports, notifications, OTP login, and WhatsApp webhook support.

## Project Structure

```text
backend/   Laravel API backend
frontend/  Flutter web/mobile/admin application
scripts/   Local smoke-test helpers
docs/      Deployment, API, and operating notes
```

## Implemented Features

### ERP and Store Operations

- Product catalog with categories, brands, images, prices, cost prices, pack units, and stock totals.
- Inventory by warehouse with manual adjustments and stock movement audit records.
- Procurement module with suppliers, purchase orders, receiving, and inventory restock integration.
- Bulk product, brand, and category import/export.
- Order management with retailer identity, delivery address, delivery coordinates, status workflow, distributor assignment, delivery proof fields, and cancellation.
- Invoice generation, status tracking, customizable due dates, date filters, and bulk invoice printing.
- Payments and outstanding balance reporting.

### CRM

- Retailer/customer account overview.
- Retailer order history, balances, missing delivery pin filtering, and account details.
- Sales representative management and retailer onboarding.
- Cash collection and representative feature controls.

### Promotions and Notifications

- Percentage, fixed amount, bulk tier, and buy-X-get-Y promotion engine.
- Product-specific, brand-specific, and category-specific promotion targeting.
- Notifications for:
  - New products.
  - Products restocked from out-of-stock.
  - New or activated promotions.
  - Promotion updates.
- Notification inbox with unread filtering and event-type filters.

### Reports

- Real backend sales metrics instead of mock dashboard values.
- Sales, paid amounts, outstanding balance, order totals, open orders, active retailers, daily sales, status breakdown, retailer summary, and product summary.
- Filters by:
  - Custom date from/to.
  - Order status.
  - Payment status.
  - Retailer.
  - Distributor.
  - Brand.
  - Category.
  - Min/max order totals.

### Delivery and Dispatch

- Dispatch order listing.
- Map assignment and delivery batch support.
- Delivery pin and coordinates support.
- Delivery proof fields for signature/photo.

### Authentication and Messaging

- JWT authentication.
- OTP login via SMS or WhatsApp channel.
- Database-backed outbound message queue.
- WhatsApp Cloud API sending support.
- Public Meta WhatsApp webhook verification and inbound/status callback handling.

## Backend

The backend is a Laravel application in `backend/`.

Important routes include:

```text
POST /api/v1/auth/login
POST /api/v1/auth/otp/request
POST /api/v1/auth/otp/verify

GET  /api/v1/products
POST /api/v1/products
GET  /api/v1/catalog/export
POST /api/v1/catalog/import

GET  /api/v1/orders
POST /api/v1/orders
PUT  /api/v1/orders/{order}/status
POST /api/v1/orders/{order}/assign
POST /api/v1/orders/{order}/deliver

GET  /api/v1/inventory
POST /api/v1/inventory/adjust

GET  /api/v1/suppliers
POST /api/v1/suppliers
GET  /api/v1/purchase-orders
POST /api/v1/purchase-orders
POST /api/v1/purchase-orders/{purchaseOrder}/receive

GET  /api/v1/promotions
POST /api/v1/promotions
POST /api/v1/promotions/calculate

GET  /api/v1/reports/sales

GET  /api/v1/invoices
POST /api/v1/invoices
PUT  /api/v1/invoices/{id}/status

GET  /api/v1/notifications
PUT  /api/v1/notifications/{id}/read
PUT  /api/v1/notifications/read-all

GET  /api/v1/whatsapp/webhook
POST /api/v1/whatsapp/webhook
```

## Frontend

The frontend is a Flutter application in `frontend/`.

It includes:

- Admin ERP dashboard.
- Reports.
- Orders.
- CRM.
- Dispatch map.
- Retailer onboarding.
- Sales reps.
- Catalog.
- Promotions.
- Inventory.
- Procurement.
- Notifications.
- Invoices.
- Audit log.
- Retailer catalog/cart/orders/payments.
- Distributor delivery list/detail flows.

## Local Setup

### Backend

```bash
cd backend
composer install
cp .env.example .env
php artisan key:generate
php artisan migrate
php artisan test
```

### Frontend

```bash
cd frontend
flutter pub get
flutter analyze
flutter build web
```

For a custom API base URL:

```bash
flutter build web --dart-define=BMP_API_BASE_URL=https://your-domain.example/api/v1
```

## Production Notes

Never commit real secrets. Configure these only in the server environment or server `.env`:

```text
APP_KEY
DB_*
SMS_GATEWAY_TOKEN
WHATSAPP_ACCESS_TOKEN
WHATSAPP_PHONE_NUMBER_ID
WHATSAPP_WEBHOOK_VERIFY_TOKEN
DEPLOY_SETUP_TOKEN
```

For Alwaysdata/Laravel, point the web root to the public entry folder. In the prepared FTP deployment package, that is:

```text
/home/halawat/www
```

The Laravel app code lives outside the web root:

```text
/home/halawat/backend
```

## WhatsApp Webhooks

Meta callback URL:

```text
https://your-domain.example/api/v1/whatsapp/webhook
```

The verification request is handled by:

```text
GET /api/v1/whatsapp/webhook?hub.mode=subscribe&hub.verify_token=TOKEN&hub.challenge=CHALLENGE
```

Inbound messages and status callbacks are handled by:

```text
POST /api/v1/whatsapp/webhook
```

## Validation

Recent checks completed in this workspace:

```text
Backend tests: 26 tests, 175 assertions passed
Flutter analyze: no issues found
WhatsApp webhook focused test: passed
```

## Security

This repository should not include:

- `.env`
- FTP credentials
- deployment tokens
- local SQLite databases
- Laravel logs/cache/session files
- Flutter build outputs
- dependency folders such as `vendor/`, `node_modules/`, `.dart_tool/`

