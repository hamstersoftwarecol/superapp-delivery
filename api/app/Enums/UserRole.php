<?php

namespace App\Enums;

enum UserRole: string
{
    case Customer = 'customer';
    case Restaurant = 'restaurant';
    case Courier = 'courier';
}
