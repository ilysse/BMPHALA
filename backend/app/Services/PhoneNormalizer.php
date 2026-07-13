<?php

namespace App\Services;

use InvalidArgumentException;

class PhoneNormalizer
{
    public function normalize(string $phone): string
    {
        $phone = trim($phone);
        $phone = preg_replace('/[\s().-]+/', '', $phone) ?? '';

        if (str_starts_with($phone, '00')) {
            $phone = '+' . substr($phone, 2);
        }

        if (!str_starts_with($phone, '+')) {
            if (preg_match('/^0[5-7]\d{8}$/', $phone) === 1) {
                $phone = '+212' . substr($phone, 1);
            } elseif (preg_match('/^[5-7]\d{8}$/', $phone) === 1) {
                $phone = '+212' . $phone;
            } else {
                throw new InvalidArgumentException('Enter a phone number with country code.');
            }
        }

        if (preg_match('/^\+[1-9]\d{7,14}$/', $phone) !== 1) {
            throw new InvalidArgumentException('Enter a valid phone number.');
        }

        return $phone;
    }
}
