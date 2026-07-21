<?php

namespace App\Scopes;

use Illuminate\Database\Eloquent\Builder;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Scope;
use App\Services\TenantManager;

class CompanyScope implements Scope
{
    public function apply(Builder $builder, Model $model): void
    {
        $companyId = TenantManager::getCompanyId();
        if ($companyId) {
            $builder->where($model->getTable() . '.company_id', $companyId);
        }
    }
}
