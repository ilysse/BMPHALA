<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Http\Traits\ApiResponse;
use App\Models\Permission;
use App\Models\Role;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Validator;
use Illuminate\Support\Str;

class RoleController extends Controller
{
    use ApiResponse;

    /**
     * List all roles for the authenticated company.
     *
     * GET /api/v1/roles
     */
    public function index(Request $request): JsonResponse
    {
        $query = Role::with('permissions');

        if ($request->filled('search')) {
            $query->where('name', 'like', "%{$request->search}%");
        }

        $perPage = min($request->integer('per_page', 15), 100);
        $roles   = $query->orderBy('name')->paginate($perPage);

        return $this->success(
            $roles->items(),
            'Roles retrieved successfully.',
            200,
            $this->paginationMeta($roles)
        );
    }

    /**
     * Show a single role with its permissions.
     *
     * GET /api/v1/roles/{id}
     */
    public function show(string $id): JsonResponse
    {
        $role = Role::with('permissions')->find($id);

        if (!$role) {
            return $this->notFound('Role not found.');
        }

        return $this->success($role, 'Role retrieved successfully.');
    }

    /**
     * Create a new role.
     *
     * POST /api/v1/roles
     */
    public function store(Request $request): JsonResponse
    {
        $validator = Validator::make($request->all(), [
            'name'        => 'required|string|max:255',
            'description' => 'nullable|string|max:500',
        ]);

        if ($validator->fails()) {
            return $this->validationError($validator->errors()->toArray());
        }

        $companyId = auth()->user()->company_id;

        // Check for duplicate role name within the company
        $exists = Role::where('name', $request->name)->exists();

        if ($exists) {
            return $this->validationError([
                'name' => ['A role with this name already exists in this company.'],
            ]);
        }

        $role = Role::create([
            'id'          => (string) Str::ulid(),
            'company_id'  => $companyId,
            'name'        => $request->name,
            'description' => $request->description,
        ]);

        return $this->created($role->load('permissions'), 'Role created successfully.');
    }

    /**
     * Update an existing role.
     *
     * PUT /api/v1/roles/{id}
     */
    public function update(Request $request, string $id): JsonResponse
    {
        $role = Role::find($id);

        if (!$role) {
            return $this->notFound('Role not found.');
        }

        $validator = Validator::make($request->all(), [
            'name'        => 'sometimes|string|max:255',
            'description' => 'nullable|string|max:500',
        ]);

        if ($validator->fails()) {
            return $this->validationError($validator->errors()->toArray());
        }

        // If name is changing, check for duplicates
        if ($request->filled('name') && $request->name !== $role->name) {
            $exists = Role::where('name', $request->name)
                ->where('id', '!=', $role->id)
                ->exists();

            if ($exists) {
                return $this->validationError([
                    'name' => ['A role with this name already exists in this company.'],
                ]);
            }
        }

        $role->update($request->only(['name', 'description']));

        return $this->success($role->fresh()->load('permissions'), 'Role updated successfully.');
    }

    /**
     * Delete a role.
     *
     * DELETE /api/v1/roles/{id}
     */
    public function destroy(string $id): JsonResponse
    {
        $role = Role::find($id);

        if (!$role) {
            return $this->notFound('Role not found.');
        }

        // Prevent deletion of system roles
        $systemRoles = ['admin', 'retailer', 'distributor', 'sales_rep'];
        if (in_array($role->name, $systemRoles)) {
            return $this->error('System roles cannot be deleted.', 422, [
                'role' => ['The role "' . $role->name . '" is a system role and cannot be deleted.'],
            ]);
        }

        $role->delete();

        return $this->success(null, 'Role deleted successfully.');
    }

    /**
     * Attach permissions to a role.
     *
     * POST /api/v1/roles/{id}/permissions
     */
    public function attachPermissions(Request $request, string $id): JsonResponse
    {
        $role = Role::find($id);

        if (!$role) {
            return $this->notFound('Role not found.');
        }

        $validator = Validator::make($request->all(), [
            'permission_ids'   => 'required|array|min:1',
            'permission_ids.*' => 'required|string',
        ]);

        if ($validator->fails()) {
            return $this->validationError($validator->errors()->toArray());
        }

        $companyId = auth()->user()->company_id;

        // Verify all permissions belong to this company
        $validPermissions = Permission::whereIn('id', $request->permission_ids)->pluck('id');

        if ($validPermissions->count() !== count($request->permission_ids)) {
            return $this->error('One or more permissions are invalid.', 422, [
                'permission_ids' => ['Some permission IDs do not exist or belong to a different company.'],
            ]);
        }

        // Attach with company_id pivot data (sync without detaching to avoid duplicates)
        $pivotData = $validPermissions->mapWithKeys(fn ($permId) => [
            $permId => ['company_id' => $companyId],
        ])->toArray();

        $role->permissions()->syncWithoutDetaching($pivotData);

        return $this->success(
            $role->fresh()->load('permissions'),
            'Permissions attached successfully.'
        );
    }

    /**
     * Detach permissions from a role.
     *
     * DELETE /api/v1/roles/{id}/permissions
     */
    public function detachPermissions(Request $request, string $id): JsonResponse
    {
        $role = Role::find($id);

        if (!$role) {
            return $this->notFound('Role not found.');
        }

        $validator = Validator::make($request->all(), [
            'permission_ids'   => 'required|array|min:1',
            'permission_ids.*' => 'required|string',
        ]);

        if ($validator->fails()) {
            return $this->validationError($validator->errors()->toArray());
        }

        $role->permissions()->detach($request->permission_ids);

        return $this->success(
            $role->fresh()->load('permissions'),
            'Permissions detached successfully.'
        );
    }
}
