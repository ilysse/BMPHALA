<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Models\Payment;
use App\Models\Order;
use App\Http\Requests\Api\V1\StorePaymentRequest;
use App\Http\Resources\Api\V1\PaymentResource;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;

class PaymentController extends Controller
{
    public function index(Request $request)
    {
        $query = Payment::query();
        $user = auth()->user();

        if ($user->role === 'retailer') {
            $orderIds = Order::where('retailer_id', $user->id)->pluck('id');
            $query->whereIn('order_id', $orderIds);
        } elseif ($user->role === 'sales_rep') {
            $orderIds = Order::whereHas('retailer', function ($q) use ($user) {
                $q->where('metadata->responsible_id', $user->id);
            })->pluck('id');
            $query->whereIn('order_id', $orderIds);
        } elseif ($user->role === 'distributor') {
            $orderIds = Order::where('distributor_id', $user->id)->pluck('id');
            $query->whereIn('order_id', $orderIds);
        }

        if ($request->filled('order_id')) {
            $query->where('order_id', $request->order_id);
        }

        $payments = $query->orderBy('created_at', 'desc')
            ->paginate($request->integer('per_page', 15));

        return response()->json([
            'success' => true,
            'message' => 'Payments retrieved successfully.',
            'data' => PaymentResource::collection($payments->items()),
            'meta' => [
                'page' => $payments->currentPage(),
                'per_page' => $payments->perPage(),
                'total' => $payments->total(),
                'last_page' => $payments->lastPage(),
            ],
            'errors' => null
        ]);
    }

    public function store(StorePaymentRequest $request)
    {
        $data = $request->validated();
        $order = Order::find($data['order_id']);
        $collector = auth()->user();

        if (!$this->canRecordCashPayment($collector, $order)) {
            return response()->json([
                'success' => false,
                'message' => 'Cash collection is not enabled for this user.',
                'data' => null,
                'meta' => null,
                'errors' => ['cash_collection' => ['Cash collection is not enabled for this user.']],
            ], 403);
        }

        return DB::transaction(function () use ($data, $order) {
            $payment = Payment::create([
                'id' => (string) Str::ulid(),
                'company_id' => $order->company_id,
                'order_id' => $order->id,
                'amount' => $data['amount'],
                'payment_method' => 'cash',
                'payment_status' => 'completed',
                'transaction_reference' => $data['reference_number'] ?? null,
                'notes' => $data['notes'] ?? null,
            ]);

            // Update order payment status
            $totalPaid = Payment::where('order_id', $order->id)
                ->where('payment_status', 'completed')
                ->sum('amount');

            if ($totalPaid >= $order->grand_total) {
                $order->payment_status = 'paid';
            } elseif ($totalPaid > 0) {
                $order->payment_status = 'partially_paid';
            }
            $order->save();

            return response()->json([
                'success' => true,
                'message' => 'Payment recorded successfully.',
                'data' => new PaymentResource($payment),
                'meta' => null,
                'errors' => null
            ], 201);
        });
    }

    private function canRecordCashPayment($collector, Order $order): bool
    {
        if (!$collector || !in_array($collector->role, ['admin', 'sales_rep', 'distributor'], true)) {
            return false;
        }

        if (!($collector->metadata['can_collect_cash'] ?? false)) {
            return false;
        }

        if ($collector->role === 'distributor') {
            return $order->distributor_id === $collector->id;
        }

        if ($collector->role === 'sales_rep') {
            return ($order->retailer?->metadata['responsible_id'] ?? null) === $collector->id;
        }

        return $collector->company_id === $order->company_id;
    }

    public function summary($customerId)
    {
        $user = auth()->user();
        $customer = \App\Models\User::find($customerId);

        if (!$customer || $customer->role !== 'retailer') {
            return response()->json([
                'success' => false,
                'message' => 'Retailer not found.',
                'data' => null,
                'meta' => null,
                'errors' => ['customer' => ['Retailer not found.']],
            ], 404);
        }

        if ($user->role === 'retailer' && $user->id !== $customer->id) {
            abort(403);
        }

        if (
            $user->role === 'sales_rep' &&
            (($customer->metadata['responsible_id'] ?? null) !== $user->id)
        ) {
            abort(403);
        }

        // Get total orders and payments for this retailer
        $ordersTotal = Order::where('retailer_id', $customerId)
            ->whereIn('status', ['confirmed', 'processing', 'assigned', 'in_transit', 'out_for_delivery', 'delivered'])
            ->sum('grand_total');

        $customerOrderIds = Order::where('retailer_id', $customerId)->pluck('id');
        $paymentsTotal = Payment::whereIn('order_id', $customerOrderIds)
            ->where('payment_status', 'completed')
            ->sum('amount');

        $outstandingBalance = max(0, $ordersTotal - $paymentsTotal);

        return response()->json([
            'success' => true,
            'message' => 'Payment summary retrieved.',
            'data' => [
                'total_ordered' => round($ordersTotal, 2),
                'total_paid' => round($paymentsTotal, 2),
                'outstanding_balance' => round($outstandingBalance, 2),
            ],
            'meta' => null,
            'errors' => null
        ]);
    }
}
