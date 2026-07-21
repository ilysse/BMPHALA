<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Models\NotificationTemplate;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class NotificationTemplateController extends Controller
{
    public function index(): JsonResponse
    {
        $templates = NotificationTemplate::orderBy('event_type')->get();

        return response()->json([
            'success' => true,
            'message' => 'Notification templates retrieved.',
            'data' => $templates,
            'meta' => ['count' => $templates->count()],
            'errors' => null,
        ]);
    }

    public function store(Request $request): JsonResponse
    {
        $data = $request->validate([
            'event_type' => 'required|string|max:100',
            'title_template' => 'required|string|max:255',
            'body_template' => 'required|string',
            'channel' => 'nullable|string|in:push,sms,whatsapp',
            'is_active' => 'nullable|boolean',
        ]);

        $template = NotificationTemplate::create([
            'event_type' => $data['event_type'],
            'title_template' => $data['title_template'],
            'body_template' => $data['body_template'],
            'channel' => $data['channel'] ?? 'push',
            'is_active' => $data['is_active'] ?? true,
        ]);

        return response()->json([
            'success' => true,
            'message' => 'Template created successfully.',
            'data' => $template,
            'meta' => null,
            'errors' => null,
        ], 201);
    }

    public function show(string $id): JsonResponse
    {
        $template = NotificationTemplate::findOrFail($id);

        return response()->json([
            'success' => true,
            'message' => 'Template retrieved.',
            'data' => $template,
            'meta' => null,
            'errors' => null,
        ]);
    }

    public function update(Request $request, string $id): JsonResponse
    {
        $template = NotificationTemplate::findOrFail($id);

        $data = $request->validate([
            'event_type' => 'sometimes|string|max:100',
            'title_template' => 'sometimes|string|max:255',
            'body_template' => 'sometimes|string',
            'channel' => 'sometimes|string|in:push,sms,whatsapp',
            'is_active' => 'sometimes|boolean',
        ]);

        $template->update($data);

        return response()->json([
            'success' => true,
            'message' => 'Template updated successfully.',
            'data' => $template->fresh(),
            'meta' => null,
            'errors' => null,
        ]);
    }

    public function destroy(string $id): JsonResponse
    {
        $template = NotificationTemplate::findOrFail($id);
        $template->delete();

        return response()->json([
            'success' => true,
            'message' => 'Template deleted.',
            'data' => null,
            'meta' => null,
            'errors' => null,
        ]);
    }
}
