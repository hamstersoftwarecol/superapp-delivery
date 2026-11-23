<?php

namespace Database\Seeders;

use App\Enums\OrderStatus;
use App\Models\MenuItem;
use App\Models\Order;
use App\Models\Restaurant;
use App\Models\User;
use Illuminate\Database\Seeder;

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
        $this->order($customer, $tacos, OrderStatus::Cancelled, [['Limonada', 1]]);

        $this->command?->info('Datos de demostración creados. Contraseña de todas las cuentas: '.self::PASSWORD);
    }

    /**
     * @param  array<string, mixed>  $attributes
     * @param  list<array{0: string, 1: string, 2: int}>  $menu  name, description, price in cents
     */
    private function restaurant(User $owner, array $attributes, array $menu): Restaurant
    {
        $restaurant = Restaurant::factory()->for($owner, 'owner')->create($attributes);

        foreach ($menu as [$name, $description, $priceCents]) {
            MenuItem::factory()->for($restaurant)->create([
                'name' => $name,
                'description' => $description,
                'price_cents' => $priceCents,
            ]);
        }

        return $restaurant;
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
