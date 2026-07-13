# Deploying the API on alwaysdata

## 1. Create the service

1. In alwaysdata, select PHP 8.3 or newer under **Environment > PHP**.
2. Create a MariaDB database and user under **Databases > MySQL**.
3. Create a PHP site under **Web > Sites** and set its root directory to
   `/home/YOUR_ACCOUNT/bmp-backend/public`.
4. Point the production API domain to that site and enable HTTPS.

## 2. Upload and configure

Upload the contents of this backend package to
`/home/YOUR_ACCOUNT/bmp-backend`, then connect through SSH:

```bash
cd ~/bmp-backend
cp .env.alwaysdata.example .env
composer2 install --no-dev --prefer-dist --optimize-autoloader
php artisan key:generate
```

Edit `.env` with the real domain and database credentials. Keep `APP_DEBUG=false`,
use the alwaysdata database host `mysql-YOUR_ACCOUNT.alwaysdata.net`, and keep
the database charset/collation set to `utf8mb4` for Arabic product names.

## 3. Database and cache

After uploading or importing the database yourself, run:

```bash
php artisan migrate --force
php artisan storage:link
php artisan optimize
```

The web process must be able to write to `storage` and `bootstrap/cache`.
Do not upload a local `.env`, SQLite database, test cache, or development logs.

## 4. Queue worker

If SMS, WhatsApp, or other queued jobs are enabled, add an alwaysdata scheduled
job that runs once per minute:

```bash
cd /home/YOUR_ACCOUNT/bmp-backend && php artisan queue:work --stop-when-empty --tries=3
```

## 5. Firebase push notifications

In Firebase Console, create a service account under **Project settings >
Service accounts**, download its JSON, and upload it outside the public folder
as `storage/app/firebase-service-account.json`. Never put this server credential
in the Flutter app or in Git.

Set these values in `.env` and restart the queue worker:

```env
FIREBASE_PROJECT_ID=halawatapp
FIREBASE_CREDENTIALS=storage/app/firebase-service-account.json
```

## 6. Connect the Android release

Build the Android bundle with the HTTPS API URL:

```bash
flutter build appbundle --release --dart-define=BMP_API_BASE_URL=https://YOUR_DOMAIN/api/v1
```
