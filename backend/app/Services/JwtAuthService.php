<?php

namespace App\Services;

use Firebase\JWT\JWT;
use Firebase\JWT\Key;
use Exception;

class JwtAuthService
{
    protected string $key;
    protected string $algo = 'HS256';

    public function __construct()
    {
        $this->key = config('app.key', 'some-fallback-secret-key');
        if (str_starts_with($this->key, 'base64:')) {
            $this->key = base64_decode(substr($this->key, 7));
        }
    }

    /**
     * Encode a payload into a JWT.
     */
    public function encode(array $payload, int $ttlSeconds = 86400): string
    {
        $iat = time();
        $exp = $iat + $ttlSeconds;

        $payload['iat'] = $iat;
        $payload['exp'] = $exp;

        return JWT::encode($payload, $this->key, $this->algo);
    }

    /**
     * Decode a JWT token.
     */
    public function decode(string $token): ?array
    {
        try {
            $decoded = JWT::decode($token, new Key($this->key, $this->algo));
            return (array) $decoded;
        } catch (Exception $e) {
            return null;
        }
    }
}
