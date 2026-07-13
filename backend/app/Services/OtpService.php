<?php

namespace App\Services;

use App\Models\OtpChallenge;
use App\Models\User;
use App\Models\FeatureFlag;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Str;
use RuntimeException;

class OtpService
{
    public function __construct(
        private readonly PhoneNormalizer $phoneNormalizer,
        private readonly WhatsAppCloudProvider $messageProvider,
    ) {
    }

    public function request(string $phone, string $channel, ?string $ipAddress = null): OtpChallenge
    {
        $channel = $this->normalizeChannel($channel);
        $normalized = $this->phoneNormalizer->normalize($phone);
        $user = $this->findActiveUserByPhone($normalized);

        if (!$user) {
            throw new RuntimeException('If this phone is registered, an OTP will be sent.');
        }

        $this->ensureOtpEnabled($user);

        $recentCount = OtpChallenge::query()
            ->where('normalized_phone', $normalized)
            ->where('channel', $channel)
            ->where('purpose', 'login')
            ->where('created_at', '>=', now()->subMinutes(15))
            ->count();

        if ($recentCount >= 3) {
            throw new RuntimeException('Too many OTP requests. Try again later.');
        }

        OtpChallenge::query()
            ->where('normalized_phone', $normalized)
            ->where('channel', $channel)
            ->where('purpose', 'login')
            ->whereNull('consumed_at')
            ->update(['consumed_at' => now()]);

        $code = (string) random_int(100000, 999999);
        $ttl = (int) env('OTP_CODE_TTL_MINUTES', 5);
        $metadata = [
            'user_id' => $user->id,
        ];

        if (app()->environment('testing')) {
            $metadata['test_code'] = $code;
        }

        $challenge = OtpChallenge::create([
            'id' => (string) Str::ulid(),
            'company_id' => $user->company_id,
            'phone' => $phone,
            'normalized_phone' => $normalized,
            'channel' => $channel,
            'purpose' => 'login',
            'code_hash' => Hash::make($code),
            'expires_at' => now()->addMinutes($ttl),
            'resend_count' => $recentCount,
            'ip_address' => $ipAddress,
            'metadata' => $metadata,
        ]);

        $body = "Your BMP login code is {$code}. It expires in {$ttl} minutes.";
        $this->messageProvider->send($channel, $normalized, $body, [
            'otp_challenge_id' => $challenge->id,
            'purpose' => 'login',
        ]);

        return $challenge;
    }

    public function verify(string $phone, string $channel, string $code): User
    {
        $channel = $this->normalizeChannel($channel);
        $normalized = $this->phoneNormalizer->normalize($phone);

        $user = $this->findActiveUserByPhone($normalized);
        if (!$user) {
            throw new RuntimeException('The OTP code is expired or invalid.');
        }
        $this->ensureOtpEnabled($user);

        $challenge = OtpChallenge::query()
            ->where('normalized_phone', $normalized)
            ->where('channel', $channel)
            ->where('purpose', 'login')
            ->whereNull('consumed_at')
            ->latest()
            ->first();

        if (!$challenge || $challenge->expires_at->isPast()) {
            throw new RuntimeException('The OTP code is expired or invalid.');
        }

        if ($challenge->attempts >= 5) {
            throw new RuntimeException('Too many OTP attempts. Request a new code.');
        }

        if (!Hash::check($code, $challenge->code_hash)) {
            $challenge->increment('attempts');
            throw new RuntimeException('The OTP code is incorrect.');
        }

        $challenge->update(['consumed_at' => now()]);

        return $user;
    }

    private function normalizeChannel(string $channel): string
    {
        $channel = strtolower(trim($channel ?: env('OTP_DEFAULT_CHANNEL', 'sms')));
        if (!in_array($channel, ['sms', 'whatsapp'], true)) {
            throw new RuntimeException('OTP channel must be sms or whatsapp.');
        }

        return $channel;
    }

    private function findActiveUserByPhone(string $normalized): ?User
    {
        return $this->findUserByNormalizedPhone($normalized, 'active');
    }

    public function findUserByPhone(string $phone): ?User
    {
        return $this->findUserByNormalizedPhone(
            $this->phoneNormalizer->normalize($phone)
        );
    }

    private function findUserByNormalizedPhone(string $normalized, ?string $status = null): ?User
    {
        $users = User::withoutGlobalScopes()
            ->when($status, fn ($query) => $query->where('status', $status))
            ->get();

        foreach ($users as $user) {
            $phone = $user->metadata['phone'] ?? null;
            if (!$phone) {
                continue;
            }

            try {
                if ($this->phoneNormalizer->normalize($phone) === $normalized) {
                    return $user;
                }
            } catch (\InvalidArgumentException) {
                continue;
            }
        }

        return null;
    }

    public function phoneInUse(string $phone): bool
    {
        return $this->findUserByPhone($phone) !== null;
    }

    private function ensureOtpEnabled(User $user): void
    {
        $flag = FeatureFlag::withoutGlobalScopes()
            ->where('company_id', $user->company_id)
            ->where('key', 'otp_login')
            ->first();

        if ($flag && !$flag->is_enabled) {
            throw new RuntimeException('OTP login is disabled for this company.');
        }
    }
}
