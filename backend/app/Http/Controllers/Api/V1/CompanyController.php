<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Models\Company;
use Illuminate\Http\Request;

class CompanyController extends Controller
{
    public function show()
    {
        return response()->json([
            'success' => true,
            'message' => 'Company profile retrieved.',
            'data' => $this->currentCompany(),
            'meta' => null,
            'errors' => null,
        ]);
    }

    public function update(Request $request)
    {
        abort_unless(auth()->user()?->role === 'admin', 403, 'Only admins can update company settings.');

        $data = $request->validate([
            'name' => ['required', 'string', 'max:255'],
            'email' => ['nullable', 'email', 'max:255'],
            'phone' => ['nullable', 'string', 'max:30'],
            'tax_id' => ['nullable', 'string', 'max:100'],
            'logo_url' => ['nullable', 'string', 'max:500'],
            'address' => ['nullable', 'string', 'max:500'],
        ]);

        $company = $this->currentCompany();
        $company->fill($data)->save();

        return response()->json([
            'success' => true,
            'message' => 'Company profile updated.',
            'data' => $company->fresh(),
            'meta' => null,
            'errors' => null,
        ]);
    }

    private function currentCompany(): Company
    {
        return Company::findOrFail(auth()->user()->company_id);
    }
}
