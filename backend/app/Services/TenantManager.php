<?php

namespace App\Services;

class TenantManager
{
    protected static ?string $companyId = null;

    public static function setCompanyId(?string $id): void
    {
        static::$companyId = $id;
    }

    public static function getCompanyId(): ?string
    {
        return static::$companyId;
    }
}
