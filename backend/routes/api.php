<?php

use Illuminate\Http\Request;
use Illuminate\Support\Facades\Route;

Route::get('/user', function (Request $request) {
    return $request->user();
})->middleware('auth:sanctum');

Route::get('/images', function (Request $request) {
    $path = $request->query('path');
    if (!$path) {
        abort(400, 'Path is required');
    }
    $absolutePath = storage_path('app/public/' . str_replace('storage/', '', $path));
    if (!file_exists($absolutePath)) {
        abort(404);
    }
    $mimeType = mime_content_type($absolutePath) ?: 'application/octet-stream';
    return response(file_get_contents($absolutePath), 200, [
        'Access-Control-Allow-Origin' => '*',
        'Content-Type' => $mimeType,
    ]);
});
