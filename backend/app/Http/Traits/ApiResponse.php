<?php

namespace App\Http\Traits;

use Illuminate\Http\JsonResponse;

/**
 * Standardized API response format.
 *
 * All endpoints return: { success, message, data, meta, errors }
 */
trait ApiResponse
{
    /**
     * Return a successful response.
     */
    protected function success(mixed $data = null, string $message = 'Success', int $code = 200, array $meta = null): JsonResponse
    {
        return response()->json([
            'success' => true,
            'message' => $message,
            'data'    => $data,
            'meta'    => $meta,
            'errors'  => null,
        ], $code);
    }

    /**
     * Return a created response (201).
     */
    protected function created(mixed $data = null, string $message = 'Resource created successfully.'): JsonResponse
    {
        return $this->success($data, $message, 201);
    }

    /**
     * Return an error response.
     */
    protected function error(string $message = 'An error occurred.', int $code = 400, array $errors = null): JsonResponse
    {
        return response()->json([
            'success' => false,
            'message' => $message,
            'data'    => null,
            'meta'    => null,
            'errors'  => $errors,
        ], $code);
    }

    /**
     * Return a 404 not found response.
     */
    protected function notFound(string $message = 'Resource not found.'): JsonResponse
    {
        return $this->error($message, 404);
    }

    /**
     * Return a 403 forbidden response.
     */
    protected function forbidden(string $message = 'Access denied.'): JsonResponse
    {
        return $this->error($message, 403);
    }

    /**
     * Return a 422 validation error response.
     */
    protected function validationError(array $errors, string $message = 'Validation failed.'): JsonResponse
    {
        return $this->error($message, 422, $errors);
    }

    /**
     * Build paginated meta from a LengthAwarePaginator.
     */
    protected function paginationMeta($paginator): array
    {
        return [
            'current_page' => $paginator->currentPage(),
            'last_page'    => $paginator->lastPage(),
            'per_page'     => $paginator->perPage(),
            'total'        => $paginator->total(),
        ];
    }
}
