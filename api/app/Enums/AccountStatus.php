<?php

namespace App\Enums;

enum AccountStatus: string
{
    /** Restaurants and couriers wait here until an admin reviews them. */
    case Pending = 'pending';

    case Approved = 'approved';

    /** Rejected applicants and banned accounts. Cannot sign in. */
    case Suspended = 'suspended';
}
