<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Http\Resources\Api\V1\OrderResource;
use App\Models\DispatchBatch;
use App\Models\Order;
use App\Models\User;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

class DispatchController extends Controller
{
    public function orders(Request $request)
    {
        $this->authorizeAdmin();

        $orders = $this->undispatchedOrders()
            ->orderBy('created_at')
            ->get();

        return response()->json([
            'success' => true,
            'message' => 'Undispatched orders retrieved.',
            'data' => OrderResource::collection($orders),
            'meta' => ['total' => $orders->count()],
            'errors' => null,
        ]);
    }

    public function preview(Request $request)
    {
        $this->authorizeAdmin();

        $polygon = $this->validatedPolygon($request);
        $orders = $this->ordersInsidePolygon($polygon);

        return response()->json([
            'success' => true,
            'message' => 'Dispatch zone preview calculated.',
            'data' => [
                'orders' => OrderResource::collection($orders),
                'order_count' => $orders->count(),
                'grand_total' => round($orders->sum(fn (Order $order) => (float) $order->grand_total), 2),
            ],
            'meta' => null,
            'errors' => null,
        ]);
    }

    public function assign(Request $request)
    {
        $this->authorizeAdmin();

        $data = $request->validate([
            'distributor_id' => ['required', 'string', 'exists:users,id'],
        ]);
        $polygon = $this->validatedPolygon($request);

        $distributor = User::where('role', 'distributor')->find($data['distributor_id']);
        if (!$distributor) {
            return response()->json([
                'success' => false,
                'message' => 'Selected user is not a distributor.',
                'data' => null,
                'meta' => null,
                'errors' => ['distributor_id' => ['Selected user is not a distributor.']],
            ], 422);
        }

        $orders = $this->ordersInsidePolygon($polygon);
        if ($orders->isEmpty()) {
            return response()->json([
                'success' => false,
                'message' => 'No undispatched orders were found inside this zone.',
                'data' => null,
                'meta' => null,
                'errors' => ['zone_geojson' => ['No undispatched orders were found inside this zone.']],
            ], 422);
        }

        $batch = DB::transaction(function () use ($orders, $distributor, $polygon) {
            $batch = DispatchBatch::create([
                'company_id' => auth()->user()->company_id,
                'distributor_id' => $distributor->id,
                'created_by' => auth()->id(),
                'zone_geojson' => $polygon,
                'status' => 'assigned',
            ]);

            foreach ($orders as $order) {
                $order->distributor_id = $distributor->id;
                $order->status = 'assigned';
                $order->save();

                $batch->orders()->attach($order->id, [
                    'company_id' => $order->company_id,
                ]);

                $order->history()->create([
                    'company_id' => $order->company_id,
                    'status' => 'assigned',
                    'changed_by' => auth()->id(),
                    'notes' => 'Assigned by map dispatch zone.',
                ]);
            }

            return $batch;
        });

        return response()->json([
            'success' => true,
            'message' => 'Dispatch zone assigned successfully.',
            'data' => [
                'dispatch_batch_id' => $batch->id,
                'distributor_id' => $distributor->id,
                'assigned_count' => $orders->count(),
                'orders' => OrderResource::collection($batch->orders()->with(['retailer', 'distributor', 'items'])->get()),
            ],
            'meta' => null,
            'errors' => null,
        ], 201);
    }

    private function authorizeAdmin(): void
    {
        abort_unless(auth()->user()?->role === 'admin', 403, 'Only admins can dispatch orders.');
    }

    private function undispatchedOrders()
    {
        return Order::with(['retailer', 'distributor', 'items'])
            ->whereNull('distributor_id')
            ->whereIn('status', ['pending', 'confirmed', 'processing'])
            ->whereNotNull('delivery_latitude')
            ->whereNotNull('delivery_longitude');
    }

    private function validatedPolygon(Request $request): array
    {
        $data = $request->validate([
            'zone_geojson' => ['required', 'array'],
            'zone_geojson.type' => ['required', 'in:Polygon'],
            'zone_geojson.coordinates' => ['required', 'array', 'min:1'],
            'zone_geojson.coordinates.0' => ['required', 'array', 'min:4'],
            'zone_geojson.coordinates.0.*' => ['required', 'array', 'size:2'],
            'zone_geojson.coordinates.0.*.0' => ['required', 'numeric', 'between:-180,180'],
            'zone_geojson.coordinates.0.*.1' => ['required', 'numeric', 'between:-90,90'],
        ]);

        return $data['zone_geojson'];
    }

    private function ordersInsidePolygon(array $polygon)
    {
        $ring = $polygon['coordinates'][0];

        return $this->undispatchedOrders()
            ->get()
            ->filter(fn (Order $order) => $this->pointInPolygon(
                (float) $order->delivery_longitude,
                (float) $order->delivery_latitude,
                $ring
            ))
            ->values();
    }

    private function pointInPolygon(float $longitude, float $latitude, array $ring): bool
    {
        $inside = false;
        $count = count($ring);

        for ($i = 0, $j = $count - 1; $i < $count; $j = $i++) {
            $xi = (float) $ring[$i][0];
            $yi = (float) $ring[$i][1];
            $xj = (float) $ring[$j][0];
            $yj = (float) $ring[$j][1];

            $intersects = (($yi > $latitude) !== ($yj > $latitude))
                && ($longitude < ($xj - $xi) * ($latitude - $yi) / (($yj - $yi) ?: 0.0000001) + $xi);

            if ($intersects) {
                $inside = !$inside;
            }
        }

        return $inside;
    }
}
