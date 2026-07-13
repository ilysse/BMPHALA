<?php

namespace App\Services;

use App\Models\DeviceToken;
use Firebase\JWT\JWT;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\Http;
use RuntimeException;

class FcmService
{
    public function configured(): bool
    {
        return $this->credentialsPath() !== null;
    }

    public function verifyConnection(): bool
    {
        return $this->configured() && strlen($this->accessToken()) > 20;
    }

    public function sendToUser(
        string $userId,
        string $title,
        string $body,
        array $data = [],
    ): void {
        if (!$this->configured()) {
            return;
        }

        DeviceToken::withoutGlobalScopes()
            ->where('user_id', $userId)
            ->each(function (DeviceToken $device) use ($title, $body, $data) {
                $this->sendToToken($device, $title, $body, $data);
            });
    }

    private function sendToToken(
        DeviceToken $device,
        string $title,
        string $body,
        array $data,
    ): void {
        $credentials = $this->credentials();
        $projectId = config('services.firebase.project_id') ?: $credentials['project_id'];
        $response = Http::withOptions(['verify' => $this->tlsVerification()])
            ->withToken($this->accessToken())
            ->acceptJson()
            ->timeout(15)
            ->post("https://fcm.googleapis.com/v1/projects/{$projectId}/messages:send", [
                'message' => [
                    'token' => $device->token,
                    'notification' => [
                        'title' => $title,
                        'body' => $body,
                    ],
                    'data' => $this->stringifyData($data),
                    'android' => [
                        'priority' => 'high',
                        'notification' => [
                            'channel_id' => 'halawat_notifications',
                        ],
                    ],
                ],
            ]);

        if ($response->successful()) {
            return;
        }

        $status = data_get($response->json(), 'error.details.0.errorCode');
        if (in_array($status, ['UNREGISTERED', 'INVALID_ARGUMENT'], true)) {
            $device->delete();
            return;
        }

        throw new RuntimeException('FCM request failed: '.$response->status());
    }

    private function accessToken(): string
    {
        return Cache::remember('firebase.fcm_access_token', now()->addMinutes(50), function () {
            $credentials = $this->credentials();
            $now = time();
            $assertion = JWT::encode([
                'iss' => $credentials['client_email'],
                'scope' => 'https://www.googleapis.com/auth/firebase.messaging',
                'aud' => 'https://oauth2.googleapis.com/token',
                'iat' => $now,
                'exp' => $now + 3600,
            ], $credentials['private_key'], 'RS256');

            $response = Http::withOptions(['verify' => $this->tlsVerification()])
                ->asForm()->timeout(15)->post(
                'https://oauth2.googleapis.com/token',
                [
                    'grant_type' => 'urn:ietf:params:oauth:grant-type:jwt-bearer',
                    'assertion' => $assertion,
                ],
            );

            if (!$response->successful() || !$response->json('access_token')) {
                throw new RuntimeException('Unable to obtain Firebase access token.');
            }

            return (string) $response->json('access_token');
        });
    }

    private function credentials(): array
    {
        $path = $this->credentialsPath();
        if ($path === null) {
            throw new RuntimeException('Firebase credentials are not configured.');
        }

        $credentials = json_decode((string) file_get_contents($path), true);
        if (!is_array($credentials)
            || empty($credentials['client_email'])
            || empty($credentials['private_key'])
            || empty($credentials['project_id'])) {
            throw new RuntimeException('Firebase service-account JSON is invalid.');
        }

        return $credentials;
    }

    private function credentialsPath(): ?string
    {
        $configured = (string) config('services.firebase.credentials');
        if ($configured === '') {
            return null;
        }

        $path = str_starts_with($configured, DIRECTORY_SEPARATOR)
            || preg_match('/^[A-Za-z]:[\\\\\/]/', $configured)
            ? $configured
            : base_path($configured);

        return is_file($path) ? $path : null;
    }

    private function stringifyData(array $data): array
    {
        return collect($data)->mapWithKeys(function ($value, $key) {
            return [(string) $key => is_scalar($value) || $value === null
                ? (string) $value
                : json_encode($value, JSON_UNESCAPED_UNICODE)];
        })->all();
    }

    private function tlsVerification(): bool|string
    {
        $bundle = (string) config('services.firebase.ca_bundle');
        return $bundle !== '' ? $bundle : true;
    }
}
