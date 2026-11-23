<?php

namespace App\Enums;

/** Who moved an order to its current status. */
enum OrderActor: string
{
    case Customer = 'customer';
    case Restaurant = 'restaurant';
    case Courier = 'courier';

    /** Automatic rules (timeouts) and account suspensions. */
    case System = 'system';

    public static function forRole(?UserRole $role): self
    {
        return match ($role) {
            UserRole::Customer => self::Customer,
            UserRole::Restaurant => self::Restaurant,
            UserRole::Courier => self::Courier,
            UserRole::Admin, null => self::System,
        };
    }
}
