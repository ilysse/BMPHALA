<?php

namespace App\Providers;

use App\Services\JwtAuthService;
use Illuminate\Support\ServiceProvider;

class AppServiceProvider extends ServiceProvider
{
    /**
     * Register any application services.
     */
    public function register(): void
    {
        $this->app->singleton(JwtAuthService::class, function ($app) {
            return new JwtAuthService();
        });
    }

    /**
     * Bootstrap any application services.
     */
    public function boot(): void
    {
        \Illuminate\Support\Facades\Auth::extend('jwt', function ($app, $name, array $config) {
            return new \App\Auth\JwtGuard(
                \Illuminate\Support\Facades\Auth::createUserProvider($config['provider']),
                $app['request'],
                $app->make(JwtAuthService::class)
            );
        });
    }
}
