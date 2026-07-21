<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Artisan;
use Illuminate\Support\Facades\File;

class DeploymentController extends Controller
{
    public function migrate(Request $request)
    {
        $token = (string) env('DEPLOY_SETUP_TOKEN');

        abort_if($token === '' || !hash_equals($token, (string) $request->query('token')), 403);

        if (env('DB_CONNECTION') === 'sqlite') {
            $database = (string) env('DB_DATABASE');
            if ($database !== '' && !File::exists($database)) {
                File::ensureDirectoryExists(dirname($database));
                File::put($database, '');
            }
        }

        Artisan::call('migrate', ['--force' => true]);

        return response()->json([
            'success' => true,
            'message' => 'Deployment migrations completed.',
            'data' => [
                'output' => Artisan::output(),
            ],
            'meta' => null,
            'errors' => null,
        ]);
    }
}
