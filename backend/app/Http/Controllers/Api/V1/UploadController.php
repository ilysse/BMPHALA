<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Storage;

class UploadController extends Controller
{
    public function store(Request $request)
    {
        $request->validate([
            'file' => 'required|image|mimes:jpeg,png,jpg,webp,gif,svg|max:5120',
        ]);

        if ($request->hasFile('file')) {
            $path = $request->file('file')->store('uploads', 'public');

            return response()->json([
                'success' => true,
                'message' => 'Image uploaded successfully.',
                'data' => [
                    'path' => $path,
                    'url' => url('api/v1/images?path=' . urlencode($path)),
                ],
                'meta' => null,
                'errors' => null
            ], 200);
        }

        return response()->json([
            'success' => false,
            'message' => 'No file uploaded.',
            'data' => null,
            'meta' => null,
            'errors' => ['file' => 'No file uploaded']
        ], 400);
    }
}
