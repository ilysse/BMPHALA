<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Models\PromotionRule;
use App\Services\PromotionEngine;
use App\Services\NotificationBroadcaster;
use App\Http\Requests\Api\V1\StorePromotionRequest;
use App\Http\Resources\Api\V1\PromotionRuleResource;
use Illuminate\Http\Request;
use Illuminate\Support\Str;

class PromotionController extends Controller
{
    protected PromotionEngine $promotionEngine;

    public function __construct(PromotionEngine $promotionEngine)
    {
        $this->promotionEngine = $promotionEngine;
    }

    public function index(Request $request)
    {
        $query = PromotionRule::query();

        if ($request->has('active')) {
            $query->where('is_active', $request->boolean('active'));
        }

        $promotions = $query->orderBy('priority', 'desc')->get();

        return response()->json([
            'success' => true,
            'message' => 'Promotions retrieved.',
            'data' => PromotionRuleResource::collection($promotions),
            'meta' => null,
            'errors' => null
        ]);
    }

    public function store(StorePromotionRequest $request)
    {
        $data = $request->validated();
        $data['configuration'] = $this->normalizeConfiguration($request->input('configuration', []));

        $promotion = PromotionRule::create(array_merge($data, [
            'id' => (string) Str::ulid(),
        ]));

        if ($promotion->is_active) {
            app(NotificationBroadcaster::class)->promotionActivated($promotion);
        }

        return response()->json([
            'success' => true,
            'message' => 'Promotion created.',
            'data' => new PromotionRuleResource($promotion),
            'meta' => null,
            'errors' => null
        ], 201);
    }

    public function show(string $promotion)
    {
        $promotion = PromotionRule::findOrFail($promotion);

        return response()->json([
            'success' => true,
            'message' => 'Promotion retrieved.',
            'data' => new PromotionRuleResource($promotion),
            'meta' => null,
            'errors' => null
        ]);
    }

    public function update(StorePromotionRequest $request, string $promotion)
    {
        $promotion = PromotionRule::findOrFail($promotion);
        $wasActive = (bool) $promotion->is_active;
        $data = $request->validated();
        $data['configuration'] = $this->normalizeConfiguration($request->input('configuration', []));

        $promotion->update($data);
        $promotionChanged = $promotion->wasChanged(['name', 'type', 'configuration', 'start_date', 'end_date']);
        $promotion->refresh();

        if ($promotion->is_active && (!$wasActive || $promotionChanged)) {
            app(NotificationBroadcaster::class)->promotionActivated(
                $promotion,
                $wasActive ? 'updated' : 'activated'
            );
        }

        return response()->json([
            'success' => true,
            'message' => 'Promotion updated.',
            'data' => new PromotionRuleResource($promotion),
            'meta' => null,
            'errors' => null
        ]);
    }

    public function destroy(string $promotion)
    {
        $promotion = PromotionRule::findOrFail($promotion);
        $promotion->delete();

        return response()->json([
            'success' => true,
            'message' => 'Promotion deleted.',
            'data' => null,
            'meta' => null,
            'errors' => null
        ]);
    }

    public function calculate(Request $request)
    {
        $request->validate([
            'items' => 'required|array|min:1',
            'items.*.product_id' => 'required|exists:products,id',
            'items.*.quantity' => 'required|integer|min:1',
        ]);

        $breakdown = $this->promotionEngine->calculate($request->input('items'));

        return response()->json([
            'success' => true,
            'message' => 'Promotion calculation completed.',
            'data' => $breakdown,
            'meta' => null,
            'errors' => null
        ]);
    }

    private function normalizeConfiguration(mixed $configuration): array
    {
        if (is_string($configuration)) {
            $configuration = json_decode($configuration, true);
        }

        return is_array($configuration) ? $configuration : [];
    }
}
