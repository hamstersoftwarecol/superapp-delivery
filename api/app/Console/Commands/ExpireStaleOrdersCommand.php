<?php

namespace App\Console\Commands;

use App\Actions\ExpireStaleOrders;
use Illuminate\Console\Attributes\Description;
use Illuminate\Console\Attributes\Signature;
use Illuminate\Console\Command;

#[Signature('orders:expire-stale')]
#[Description('Cancela o devuelve al pool los pedidos que nadie atendió a tiempo (se ejecuta cada minuto).')]
class ExpireStaleOrdersCommand extends Command
{
    public function handle(ExpireStaleOrders $expireStaleOrders): int
    {
        $result = $expireStaleOrders->handle();

        $this->info(sprintf(
            'Cancelados sin respuesta del restaurante: %d · Cancelados sin repartidor: %d · Devueltos al pool: %d',
            $result['cancelled_pending'],
            $result['cancelled_unclaimed'],
            $result['released'],
        ));

        return self::SUCCESS;
    }
}
