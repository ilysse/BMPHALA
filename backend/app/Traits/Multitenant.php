<?php

namespace App\Traits;

use App\Scopes\CompanyScope;
use App\Services\TenantManager;
use Illuminate\Support\Str;

trait Multitenant
{
    public static function bootMultitenant(): void
    {
        static::addGlobalScope(new CompanyScope);

        static::creating(function ($model) {
            // Automatically set company_id if not already set
            if (empty($model->company_id)) {
                $model->company_id = TenantManager::getCompanyId();
            }
            
            // Automatically generate ULID if key is empty and uses ULID (string primary key)
            if (empty($model->{$model->getKeyName()}) && $model->getKeyType() === 'string') {
                $model->{$model->getKeyName()} = (string) Str::ulid();
            }
        });
    }

    /**
     * Get the value indicating whether the IDs are incrementing.
     */
    public function getIncrementing(): bool
    {
        return false;
    }

    /**
     * Get the auto-incrementing key type.
     */
    public function getKeyType(): string
    {
        return 'string';
    }
}
