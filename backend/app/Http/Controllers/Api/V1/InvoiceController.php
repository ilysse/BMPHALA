<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Models\Invoice;
use App\Models\Order;
use Illuminate\Http\Request;
use Illuminate\Http\JsonResponse;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Validator;

class InvoiceController extends Controller
{
    /**
     * Display a paginated listing of invoices.
     *
     * Filters: order_id, status, retailer_id, due_from, due_to, created_from, created_to.
     * Eager loads: order.
     */
    public function index(Request $request): JsonResponse
    {
        $query = Invoice::with(['order.retailer', 'order.items', 'company']);

        if ($request->filled('order_id')) {
            $query->where('order_id', $request->input('order_id'));
        }

        if ($request->filled('status')) {
            $query->where('status', $request->input('status'));
        }

        if ($request->filled('retailer_id')) {
            $query->whereHas('order', fn ($order) => $order->where('retailer_id', $request->input('retailer_id')));
        }

        if ($request->filled('due_from')) {
            $query->whereDate('due_date', '>=', $request->date('due_from'));
        }

        if ($request->filled('due_to')) {
            $query->whereDate('due_date', '<=', $request->date('due_to'));
        }

        if ($request->filled('created_from')) {
            $query->whereDate('created_at', '>=', $request->date('created_from'));
        }

        if ($request->filled('created_to')) {
            $query->whereDate('created_at', '<=', $request->date('created_to'));
        }

        if ($request->filled('search')) {
            $search = $request->input('search');
            $query->where(function ($builder) use ($search) {
                $builder->where('invoice_number', 'like', "%{$search}%")
                    ->orWhereHas('order.retailer', fn ($retailer) => $retailer->where('name', 'like', "%{$search}%")
                        ->orWhere('username', 'like', "%{$search}%"));
            });
        }

        $perPage = $request->input('per_page', 15);
        $invoices = $query->latest()->paginate($perPage);

        return response()->json([
            'success' => true,
            'message' => 'Invoices retrieved successfully.',
            'data' => $invoices->items(),
            'meta' => [
                'page' => $invoices->currentPage(),
                'per_page' => $invoices->perPage(),
                'total' => $invoices->total(),
                'last_page' => $invoices->lastPage(),
            ],
            'errors' => null,
        ]);
    }

    /**
     * Generate a new invoice for an order.
     *
     * Checks for duplicate invoices on the same order.
     * Auto-generates a unique invoice_number.
     * Sets amount_due from the order's grand_total.
     */
    public function generate(Request $request): JsonResponse
    {
        $validator = Validator::make($request->all(), [
            'order_id' => 'required|string|exists:orders,id',
            'due_date' => 'required|date',
        ]);

        if ($validator->fails()) {
            return response()->json([
                'success' => false,
                'message' => 'Validation failed.',
                'data' => null,
                'meta' => null,
                'errors' => $validator->errors(),
            ], 422);
        }

        // Check if an invoice already exists for this order
        $existingInvoice = Invoice::where('order_id', $request->input('order_id'))->first();

        if ($existingInvoice) {
            return response()->json([
                'success' => false,
                'message' => 'An invoice already exists for this order.',
                'data' => null,
                'meta' => null,
                'errors' => ['order_id' => ['An invoice has already been generated for this order.']],
            ], 422);
        }

        try {
            DB::beginTransaction();

            $order = Order::findOrFail($request->input('order_id'));

            $invoiceNumber = 'INV-' . strtoupper(substr(md5(uniqid()), 0, 8));

            $invoice = Invoice::create([
                'order_id' => $order->id,
                'invoice_number' => $invoiceNumber,
                'amount_due' => $order->grand_total,
                'due_date' => $request->input('due_date'),
                'status' => 'draft',
            ]);

            DB::commit();

            $invoice->load(['order', 'company']);

            return response()->json([
                'success' => true,
                'message' => 'Invoice generated successfully.',
                'data' => $invoice,
                'meta' => null,
                'errors' => null,
            ], 201);
        } catch (\Exception $e) {
            DB::rollBack();

            return response()->json([
                'success' => false,
                'message' => 'Failed to generate invoice.',
                'data' => null,
                'meta' => null,
                'errors' => ['exception' => $e->getMessage()],
            ], 500);
        }
    }

    /**
     * Display the specified invoice.
     *
     * Eager loads: order.items.
     */
    public function show(string $id): JsonResponse
    {
        $invoice = Invoice::with(['order.retailer', 'order.items', 'company'])->find($id);

        if (!$invoice) {
            return response()->json([
                'success' => false,
                'message' => 'Invoice not found.',
                'data' => null,
                'meta' => null,
                'errors' => null,
            ], 404);
        }

        return response()->json([
            'success' => true,
            'message' => 'Invoice retrieved successfully.',
            'data' => $invoice,
            'meta' => null,
            'errors' => null,
        ]);
    }

    /**
     * Update the status of the specified invoice.
     */
    public function updateStatus(Request $request, string $id): JsonResponse
    {
        $invoice = Invoice::find($id);

        if (!$invoice) {
            return response()->json([
                'success' => false,
                'message' => 'Invoice not found.',
                'data' => null,
                'meta' => null,
                'errors' => null,
            ], 404);
        }

        $validator = Validator::make($request->all(), [
            'status' => 'required|string|in:draft,sent,paid,overdue,cancelled',
        ]);

        if ($validator->fails()) {
            return response()->json([
                'success' => false,
                'message' => 'Validation failed.',
                'data' => null,
                'meta' => null,
                'errors' => $validator->errors(),
            ], 422);
        }

        try {
            DB::beginTransaction();

            $invoice->update(['status' => $request->input('status')]);

            DB::commit();

            return response()->json([
                'success' => true,
                'message' => 'Invoice status updated successfully.',
                'data' => $invoice,
                'meta' => null,
                'errors' => null,
            ]);
        } catch (\Exception $e) {
            DB::rollBack();

            return response()->json([
                'success' => false,
                'message' => 'Failed to update invoice status.',
                'data' => null,
                'meta' => null,
                'errors' => ['exception' => $e->getMessage()],
            ], 500);
        }
    }
}
