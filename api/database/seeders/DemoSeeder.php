<?php

namespace Database\Seeders;

use App\Actions\StoreImage;
use App\Enums\OrderActor;
use App\Enums\OrderStatus;
use App\Models\MenuItem;
use App\Models\Order;
use App\Models\Restaurant;
use App\Models\User;
use Illuminate\Database\Seeder;
use Illuminate\Support\Facades\Storage;

/**
 * Local demo data: one account per role, a few restaurants with menus and
 * orders in every stage of the delivery flow. Never runs in production.
 */
class DemoSeeder extends Seeder
{
    /** Password shared by every demo account. */
    public const PASSWORD = 'demo-password';

    public const CUSTOMER_EMAIL = 'cliente@demo.test';

    public const COURIER_EMAIL = 'repartidor@demo.test';

    public const OWNER_EMAIL = 'restaurante@demo.test';

    public const ADMIN_EMAIL = 'admin@demo.test';

    public const PENDING_COURIER_EMAIL = 'repartidor-pendiente@demo.test';

    public const PENDING_OWNER_EMAIL = 'restaurante-pendiente@demo.test';

    public function run(): void
    {
        if (app()->environment('production')) {
            $this->command?->warn('DemoSeeder se omite en producción.');

            return;
        }

        if (User::where('email', self::CUSTOMER_EMAIL)->exists()) {
            $this->command?->info('Los datos de demostración ya existen; no se vuelven a crear.');

            return;
        }

        // Rows from an earlier `migrate:fresh` are gone, so their photos are orphans.
        $images = Storage::disk(config('delivery.images.disk'));
        $images->deleteDirectory('restaurants');
        $images->deleteDirectory('menu-items');

        $customer = User::factory()->create([
            'name' => 'Cliente Demo',
            'email' => self::CUSTOMER_EMAIL,
            'phone' => '3001234567',
            'password' => self::PASSWORD,
        ]);

        $courier = User::factory()->courier()->create([
            'name' => 'Repartidor Demo',
            'email' => self::COURIER_EMAIL,
            'phone' => '3007654321',
            'password' => self::PASSWORD,
        ]);

        $owner = User::factory()->restaurantOwner()->create([
            'name' => 'Don Pepe',
            'email' => self::OWNER_EMAIL,
            'phone' => '3009876543',
            'password' => self::PASSWORD,
        ]);

        User::factory()->admin()->create([
            'name' => 'Admin Demo',
            'email' => self::ADMIN_EMAIL,
            'password' => self::PASSWORD,
        ]);

        // Waiting for an admin's review, so the approval screens have something to show.
        User::factory()->courier()->pending()->create([
            'name' => 'Repartidor Pendiente',
            'email' => self::PENDING_COURIER_EMAIL,
            'password' => self::PASSWORD,
        ]);

        User::factory()->restaurantOwner()->pending()->create([
            'name' => 'Restaurante Pendiente',
            'email' => self::PENDING_OWNER_EMAIL,
            'password' => self::PASSWORD,
        ]);

        $tacos = $this->restaurant($owner, [
            'name' => 'Tacos Don Pepe',
            'description' => 'Los mejores tacos al pastor de la ciudad.',
            'address' => 'Calle 10 # 5-20',
            'delivery_fee_cents' => 300000,
        ], [
            ['Taco al pastor', 'Con piña y cilantro', 450000],
            ['Quesadilla', 'Queso oaxaca', 620000],
            ['Burrito de pollo', 'Frijoles, arroz y guacamole', 1250000],
            ['Limonada', 'Natural, 12 oz', 300000],
        ]);

        $this->restaurant($owner, [
            'name' => 'Pizzería Napoli',
            'description' => 'Masa madre y horno de leña.',
            'address' => 'Carrera 15 # 82-14',
            'delivery_fee_cents' => 0,
        ], [
            ['Margherita', 'Tomate, mozzarella y albahaca', 2800000],
            ['Pepperoni', 'Mozzarella y pepperoni', 3200000],
            ['Tiramisú', 'Receta de la casa', 1400000],
        ]);

        $this->restaurant(User::factory()->restaurantOwner()->create([
            'name' => 'Sushi Kyoto',
            'email' => 'sushi@demo.test',
            'password' => self::PASSWORD,
        ]), [
            'name' => 'Sushi Kyoto',
            'description' => 'Cerrado por hoy: sirve para probar que no aparece en la lista.',
            'address' => 'Calle 70 # 11-30',
            'delivery_fee_cents' => 500000,
            'is_open' => false,
        ], [
            ['Roll California', '8 piezas', 2600000],
        ]);

        // One order per stage so every screen has something to show.
        $this->order($customer, $tacos, OrderStatus::Pending, [['Taco al pastor', 3]]);
        $this->order($customer, $tacos, OrderStatus::Preparing, [['Burrito de pollo', 1], ['Limonada', 1]]);
        $this->order($customer, $tacos, OrderStatus::Ready, [['Quesadilla', 2]]);
        $this->order($customer, $tacos, OrderStatus::PickedUp, [['Taco al pastor', 4]], $courier);
        $this->order($customer, $tacos, OrderStatus::Delivered, [['Burrito de pollo', 2]], $courier);

        // The ways an order can end badly, each with who decided and why.
        $this->order($customer, $tacos, OrderStatus::Cancelled, [['Limonada', 1]], reason: 'Se agotaron los ingredientes.', actor: OrderActor::Restaurant);
        $this->order($customer, $tacos, OrderStatus::Rejected, [['Quesadilla', 1]], reason: 'Estamos cerrando la cocina.', actor: OrderActor::Restaurant);
        $this->order($customer, $tacos, OrderStatus::Failed, [['Taco al pastor', 2]], $courier, 'El cliente no contestó el teléfono.', OrderActor::Courier);

        $this->command?->info('Datos de demostración creados. Contraseña de todas las cuentas: '.self::PASSWORD);
    }

    /**
     * @param  array<string, mixed>  $attributes
     * @param  list<array{0: string, 1: string, 2: int}>  $menu  name, description, price in cents
     */
    private function restaurant(User $owner, array $attributes, array $menu): Restaurant
    {
        $restaurant = Restaurant::factory()->for($owner, 'owner')->create($attributes);
        $store = app(StoreImage::class);

        $restaurant->forceFill([
            'image_path' => $store->handle($this->placeholder(crc32($restaurant->name) % 360, 1200, 800), 'restaurants'),
        ])->save();

        foreach ($menu as $index => [$name, $description, $priceCents]) {
            MenuItem::factory()->for($restaurant)->create([
                'name' => $name,
                'description' => $description,
                'price_cents' => $priceCents,
                'image_path' => $store->handle($this->placeholder(crc32($name) % 360, 800, 800), 'menu-items'),
            ]);
        }

        return $restaurant;
    }

    /**
     * A plain picture for the demo: a coloured background with a plate on it.
     * Real photos come from the restaurants themselves.
     */
    private function placeholder(int $hue, int $width, int $height): string
    {
        $image = imagecreatetruecolor($width, $height);

        for ($y = 0; $y < $height; $y++) {
            [$r, $g, $b] = $this->hslToRgb($hue, 0.6, 0.78 - 0.25 * ($y / $height));
            imageline($image, 0, $y, $width, $y, imagecolorallocate($image, $r, $g, $b));
        }

        $plate = (int) (min($width, $height) * 0.62);
        imagefilledellipse($image, intdiv($width, 2), intdiv($height, 2), $plate, $plate, imagecolorallocate($image, 250, 250, 250));
        [$r, $g, $b] = $this->hslToRgb($hue, 0.7, 0.45);
        imagefilledellipse($image, intdiv($width, 2), intdiv($height, 2), (int) ($plate * 0.62), (int) ($plate * 0.62), imagecolorallocate($image, $r, $g, $b));

        ob_start();
        imagepng($image);

        return (string) ob_get_clean();
    }

    /**
     * @return array{0: int, 1: int, 2: int}
     */
    private function hslToRgb(int $hue, float $saturation, float $lightness): array
    {
        $c = (1 - abs(2 * $lightness - 1)) * $saturation;
        $x = $c * (1 - abs(fmod($hue / 60, 2) - 1));
        $m = $lightness - $c / 2;

        [$r, $g, $b] = match (intdiv($hue, 60) % 6) {
            0 => [$c, $x, 0],
            1 => [$x, $c, 0],
            2 => [0, $c, $x],
            3 => [0, $x, $c],
            4 => [$x, 0, $c],
            default => [$c, 0, $x],
        };

        return [(int) round(($r + $m) * 255), (int) round(($g + $m) * 255), (int) round(($b + $m) * 255)];
    }

    /**
     * @param  list<array{0: string, 1: int}>  $lines  menu item name, quantity
     */
    private function order(
        User $customer,
        Restaurant $restaurant,
        OrderStatus $status,
        array $lines,
        ?User $courier = null,
        ?string $reason = null,
        ?OrderActor $actor = null,
    ): Order {
        $items = $restaurant->menuItems->whereIn('name', array_column($lines, 0))->keyBy('name');
        $quantities = array_column($lines, 1, 0);

        $subtotal = $items->sum(fn (MenuItem $item) => $item->price_cents * $quantities[$item->name]);

        $order = Order::factory()->for($customer, 'customer')->for($restaurant)->create([
            'courier_id' => $courier?->id,
            'status' => $status,
            'subtotal_cents' => $subtotal,
            'delivery_fee_cents' => $restaurant->delivery_fee_cents,
            'total_cents' => $subtotal + $restaurant->delivery_fee_cents,
            'delivery_address' => 'Carrera 7 # 40-10, apto 301',
            'status_reason' => $reason,
            'status_actor' => $actor,
        ]);

        foreach ($items as $item) {
            $order->items()->create([
                'menu_item_id' => $item->id,
                'name' => $item->name,
                'unit_price_cents' => $item->price_cents,
                'quantity' => $quantities[$item->name],
            ]);
        }

        return $order;
    }
}
