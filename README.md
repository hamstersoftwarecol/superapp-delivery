# SuperApp Delivery

Plataforma de delivery de comida con tres piezas que comparten un mismo API:

| Carpeta   | Qué es                                   | Para quién                  | Tecnología                                  |
| --------- | ---------------------------------------- | --------------------------- | ------------------------------------------- |
| `api/`    | API REST, la fuente de verdad            | Todas las apps              | Laravel 13, PostgreSQL, Redis, Sanctum      |
| `web/`    | Panel de administración                  | Restaurantes                | Next.js 16, TypeScript, Tailwind            |
| `mobile/` | App móvil (iOS y Android)                | Clientes y repartidores     | Flutter 3.50, Bloc, go_router               |

Por ahora solo hay comida y solo pago contra entrega.

## Cómo funciona un pedido

```
Cliente hace el pedido ─▶ pending ─▶ accepted ─▶ preparing ─▶ ready ─▶ picked_up ─▶ delivered
                            │ │
                            │ └─▶ rejected   (el restaurante lo rechaza)
                            └───▶ cancelled  (el cliente cancela, solo mientras está pending)
```

| Rol           | Puede hacer                                                                                      |
| ------------- | ------------------------------------------------------------------------------------------------ |
| `customer`    | Ver restaurantes abiertos, hacer pedidos, seguirlos y cancelarlos mientras estén `pending`.      |
| `restaurant`  | Crear su restaurante y su menú; aceptar, rechazar, preparar y marcar como listo (`ready`).       |
| `courier`     | Ver pedidos `ready` sin repartidor, tomarlos, marcarlos `picked_up` y `delivered`.               |

El API valida cada paso: no se pueden saltar estados y cada rol solo puede dar los suyos.

## Requisitos

Probado en macOS con estas versiones:

- PHP 8.4 y Composer 2
- PostgreSQL 17 y Redis 8
- Node 26 y pnpm 9
- Flutter 3.50 (Dart 3.14). Para iOS, Xcode completo y CocoaPods; para Android, Android Studio con su SDK.

## Puesta en marcha

### 1. API (`api/`)

```bash
createdb superapp_delivery
cd api
cp .env.example .env
composer install
php artisan key:generate
php artisan migrate --seed
php artisan serve --port=8000
```

- En `.env`, ajusta `DB_USERNAME`. Con PostgreSQL de Homebrew suele ser tu usuario de macOS, no `postgres`.
- PostgreSQL y Redis tienen que estar corriendo: `brew services start postgresql@17` y `brew services start redis`.
- `--seed` carga los datos de demostración (ver más abajo). Es seguro repetirlo: no duplica nada y no hace nada en producción.

### 2. Panel web (`web/`)

Crea `web/.env.local` (no se versiona):

```bash
API_URL=http://localhost:8000/api/v1
CURRENCY=COP
```

```bash
cd web
pnpm install
pnpm dev          # http://localhost:3000
```

### 3. App móvil (`mobile/`)

```bash
cd mobile
flutter pub get
flutter run       # elige un simulador de iOS o un emulador de Android
```

La app busca el API en `http://10.0.2.2:8000/api/v1` en Android y `http://localhost:8000/api/v1` en iOS, que son las direcciones con las que cada emulador alcanza tu Mac. Para otra dirección:

```bash
flutter run --dart-define=API_URL=http://192.168.1.20:8000/api/v1
```

> **Teléfono físico (sin probar):** `localhost` sería el propio teléfono. Haría falta usar la IP de tu Mac en `API_URL` y arrancar el API con `php artisan serve --host=0.0.0.0`.

## Cuentas de demostración

Todas usan la contraseña `demo-password` (definida en `api/database/seeders/DemoSeeder.php`).

| Correo                   | Rol          | Para probar                                                  |
| ------------------------ | ------------ | ------------------------------------------------------------ |
| `cliente@demo.test`      | customer     | App móvil: restaurantes, carrito, seguimiento de pedidos.    |
| `repartidor@demo.test`   | courier      | App móvil: pedidos disponibles y entregas.                   |
| `restaurante@demo.test`  | restaurant   | Panel web: tablero de pedidos, menú y datos del restaurante. |
| `sushi@demo.test`        | restaurant   | Dueño de un restaurante cerrado (no aparece a los clientes). |

Los datos incluyen 3 restaurantes con menú y 6 pedidos, uno en cada etapa: pendiente, en preparación, listo, en camino, entregado y cancelado.

Para volver a empezar desde cero: `php artisan migrate:fresh --seed` (borra toda la base de datos).

## Pruebas

```bash
cd api && php artisan test                                   # 28 pruebas
cd mobile && flutter test                                    # 19 pruebas
cd mobile/packages/delivery_api_client && dart test          # 7 pruebas
cd mobile/packages/delivery_repository && dart test          # 11 pruebas
cd web && pnpm lint && pnpm build                            # el panel web no tiene pruebas propias
```

Las pruebas del API usan SQLite en memoria: no necesitan PostgreSQL ni Redis.

## API (`/api/v1`)

Autenticación con token (`Authorization: Bearer <token>`). Los precios van en **centavos** enteros.

| Método y ruta                           | Quién            | Qué hace                                              |
| --------------------------------------- | ---------------- | ----------------------------------------------------- |
| `POST /auth/register`                   | público          | Crea la cuenta con un rol y devuelve el token.        |
| `POST /auth/login`                      | público          | Devuelve el token.                                    |
| `POST /auth/logout`, `GET /me`          | autenticado      | Cierra sesión / perfil.                               |
| `GET /restaurants`, `GET /restaurants/{id}` | público      | Restaurantes abiertos / uno con su menú disponible.   |
| `GET /owner/restaurants`                | restaurant       | Sus restaurantes con todo el menú.                    |
| `POST /restaurants`, `PATCH /restaurants/{id}` | restaurant | Crear y editar (solo el dueño).                     |
| `POST /restaurants/{id}/menu-items`     | restaurant       | Agregar un producto.                                  |
| `PATCH` / `DELETE /menu-items/{id}`     | restaurant       | Editar o eliminar un producto.                        |
| `POST /orders`                          | customer         | Hacer un pedido. El servidor calcula los totales.     |
| `GET /orders`, `GET /orders/{id}`       | cualquiera       | Sus pedidos, según el rol.                            |
| `PATCH /orders/{id}/status`             | según el estado  | Avanza el pedido (el API valida rol y transición).    |
| `GET /courier/available-orders`         | courier          | Pedidos `ready` sin repartidor.                       |
| `POST /orders/{id}/claim`               | courier          | Tomar un pedido (dos repartidores no pueden tomarlo). |

## Cómo está hecho

- **`api/`**: controladores delgados, `FormRequest` para validar, políticas para autorizar y acciones (`PlaceOrder`, `TransitionOrder`) para la lógica de negocio. Respuestas con API Resources.
- **`web/`**: Server Components y Server Actions. El token del API vive en una cookie `httpOnly` y todas las llamadas salen del servidor de Next.js, así que no hace falta CORS. Usa Cache Components (Next.js 16): lo que lee la sesión va dentro de `<Suspense>`.
- **`mobile/`**: capas separadas. `packages/delivery_api_client` (HTTP, sin Flutter) y `packages/delivery_repository` (modelos y repositorios, sin Flutter); en `lib/`, un Cubit por pantalla y páginas separadas de sus vistas.
- El panel y la app se actualizan consultando al API cada 8 a 10 segundos (no hay tiempo real con websockets).

## Estado y pendientes

Verificado: el ciclo completo cliente → restaurante → repartidor, en el simulador de iOS y en el emulador de Android, y el panel web en el navegador.

Aún no hay:

- **Pagos en línea.** Solo pago contra entrega. Mercado Pago está pensado para más adelante.
- **Probado en un teléfono físico** ni compilaciones de producción (HTTPS, iconos, firma de la app).
- **Notificaciones push** ni mapa/seguimiento por GPS del repartidor.
- **Traducciones.** Los textos están fijos en español.
- **Rol `admin`.** No hay panel de administración general.
- **Varios restaurantes por cuenta en el panel web.** El menú permite elegir entre ellos, pero la pantalla "Restaurante" solo edita el primero y no hay forma de crear uno segundo desde ahí.
- **Repositorio git.** La carpeta aún no está versionada.
