<?php

use Illuminate\Support\Facades\Route;
use Illuminate\Support\Facades\Storage;

Route::get('/', function () {
    return view('welcome');
});

Route::get('/sms-gateway', function () {
    return view('sms-gateway');
});

// Custom route to serve storage files with CORS headers for local development
Route::get('/storage/{path}', function ($path) {
    $path = ltrim(str_replace('\\', '/', (string) $path), '/');
    abort_if($path === '' || str_contains($path, '..') || str_contains($path, "\0"), 400, 'Invalid path');
    abort_unless(Storage::disk('public')->exists($path), 404);

    return Storage::disk('public')->response($path, null, [
        'Access-Control-Allow-Origin' => '*',
        'Cache-Control' => 'public, max-age=86400',
    ]);
})->where('path', '.*');
