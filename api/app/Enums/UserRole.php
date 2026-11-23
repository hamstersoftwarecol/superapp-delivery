<?php

namespace App\Enums;

enum UserRole: string
{
    case Customer = 'customer';
    case Restaurant = 'restaurant';
    case Courier = 'courier';
    case Admin = 'admin';

    /**
     * Roles anyone may pick when signing up. Admins are created by command.
     *
     * @return list<self>
     */
    public static function selfRegistrable(): array
    {
        return [self::Customer, self::Restaurant, self::Courier];
    }

    /** Whether accounts with this role need an admin's approval before working. */
    public function requiresApproval(): bool
    {
        return $this === self::Restaurant || $this === self::Courier;
    }
}
