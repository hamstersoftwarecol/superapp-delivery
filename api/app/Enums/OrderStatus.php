<?php

namespace App\Enums;

enum OrderStatus: string
{
    case Pending = 'pending';
    case Accepted = 'accepted';
    case Preparing = 'preparing';
    case Ready = 'ready';
    case PickedUp = 'picked_up';
    case Delivered = 'delivered';
    case Rejected = 'rejected';
    case Cancelled = 'cancelled';

    /** The courier had the order but could not hand it over. */
    case Failed = 'failed';

    /**
     * @return list<self>
     */
    public function allowedNext(): array
    {
        return match ($this) {
            self::Pending => [self::Accepted, self::Rejected, self::Cancelled],
            self::Accepted => [self::Preparing, self::Cancelled],
            self::Preparing => [self::Ready, self::Cancelled],
            self::Ready => [self::PickedUp, self::Cancelled],
            self::PickedUp => [self::Delivered, self::Failed],
            self::Delivered, self::Rejected, self::Cancelled, self::Failed => [],
        };
    }

    public function canTransitionTo(self $next): bool
    {
        return in_array($next, $this->allowedNext(), true);
    }

    public function isFinal(): bool
    {
        return $this->allowedNext() === [];
    }

    /** Whether the order can still be called off because nobody has the food yet. */
    public function isBeforePickup(): bool
    {
        return in_array($this, [self::Pending, self::Accepted, self::Preparing, self::Ready], true);
    }

    /** Whether ending the order this way needs an explanation shown to the others. */
    public function needsReason(): bool
    {
        return in_array($this, [self::Rejected, self::Cancelled, self::Failed], true);
    }
}
