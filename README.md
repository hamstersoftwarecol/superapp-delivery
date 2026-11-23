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
                            │            │           │          │          │
                            │ rejected   └───────────┴──────────┘          └─▶ failed
                            │ cancelled     cancelled (restaurante,           (el repartidor no
                            │ (cliente      o automático, antes de             pudo entregar)
                            ▼  o sistema)   que se recoja)
```

| Rol           | Puede hacer                                                                                      |
| ------------- | ------------------------------------------------------------------------------------------------ |
| `customer`    | Ver restaurantes abiertos, hacer pedidos, seguirlos y cancelarlos mientras estén `pending`.      |
| `restaurant`  | Crear su restaurante y su menú; aceptar, rechazar, preparar y marcar como listo (`ready`). Puede cancelar un pedido ya aceptado, hasta que lo recojan. |
| `courier`     | Ver pedidos `ready` sin repartidor, tomarlos, soltarlos antes de recogerlos, marcarlos `picked_up` y `delivered`, o `failed` si no pudo entregar. |
| `admin`       | Revisar las cuentas de restaurantes y repartidores: aprobarlas, rechazarlas o suspenderlas.      |

El API valida cada paso: no se pueden saltar estados y cada rol solo puede dar los suyos.

### Cuando algo sale mal

Cada final que no es una entrega guarda **quién lo decidió** (`status_actor`: cliente, restaurante, repartidor o sistema) y **por qué** (`status_reason`), y ambos se muestran en el panel y en la app.

| Situación | Qué pasa | Motivo |
| --- | --- | --- |
| El restaurante rechaza un pedido nuevo | `rejected` | Obligatorio |
| El restaurante cancela un pedido aceptado, en preparación o listo | `cancelled`. No puede si un repartidor ya lo recogió. | Obligatorio |
| El cliente cancela | Solo mientras está `pending`. Después, solo el restaurante puede cancelar. | Opcional |
| El restaurante no responde en **10 min** | `cancelled` automático | "El restaurante no respondió a tiempo." |
| Listo, sin repartidor en **30 min** | `cancelled` automático | "No hubo un repartidor disponible a tiempo." |
| Un repartidor toma el pedido y no lo recoge en **20 min** | Vuelve a quedar disponible (con una ventana nueva de 30 min) | — |
| El repartidor ya no puede recogerlo | Lo **suelta** (`POST /orders/{id}/release`) y otro lo puede tomar | — |
| El repartidor no pudo entregar | `failed` | Obligatorio |
| Se suspende un restaurante o un cliente | Sus pedidos que nadie recogió se cancelan; los que ya van en camino siguen | "El restaurante fue suspendido." |
| Se suspende un repartidor | Lo que tenía sin recoger vuelve al pool; lo que llevaba pasa a `failed` | "El repartidor fue suspendido." |

Los plazos se cambian con `ORDER_PENDING_TIMEOUT_MINUTES`, `ORDER_UNCLAIMED_TIMEOUT_MINUTES` y `ORDER_CLAIM_TIMEOUT_MINUTES` (ver `api/config/delivery.php`).

Las reglas automáticas las ejecuta el comando `php artisan orders:expire-stale`, que el planificador de Laravel lanza **cada minuto**. En desarrollo corre con `php artisan schedule:work`; en producción hace falta una tarea programada: `* * * * * cd /ruta/api && php artisan schedule:run`.

### Aprobación de cuentas

Los clientes entran directamente. Los **restaurantes y repartidores nuevos quedan en revisión** (`pending`) hasta que un administrador los apruebe:

| Estado       | Qué puede hacer la cuenta                                                                                         |
| ------------ | ----------------------------------------------------------------------------------------------------------------- |
| `pending`    | Ver su perfil y cerrar sesión. Un restaurante además puede preparar su restaurante y su menú (los clientes no lo ven). Un repartidor ve una pantalla de espera. |
| `approved`   | Trabajar con normalidad.                                                                                          |
| `suspended`  | Nada. No puede iniciar sesión, se cierran todas sus sesiones y su restaurante deja de mostrarse a los clientes.   |

Nadie puede registrarse como `admin`: esas cuentas se crean por comando (ver más abajo).

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

### Crear el primer administrador

```bash
cd api
php artisan admin:create tu@correo.com --name="Tu Nombre"
```

Pide la contraseña de forma oculta (no queda en el historial del terminal). Luego entra al panel web: verás la pantalla **Cuentas** con las solicitudes pendientes, cada una con sus datos y, si es un restaurante, el local que preparó.

### Recuperar contraseña

En el login (panel web y app móvil) hay un enlace "¿Olvidaste tu contraseña?". El API envía un correo con un enlace que abre `FRONTEND_URL/reset-password` (una página del panel web, que funciona igual para los tres roles), válido 60 minutos y de un solo uso. Al cambiar la contraseña se cierran todas las sesiones de esa cuenta. Pedir el enlace responde siempre lo mismo, exista o no el correo, y tiene límite de intentos.

- En desarrollo el correo **no se envía**: Laravel lo escribe en `api/storage/logs/laravel.log` (`MAIL_MAILER=log`). Copia de ahí el enlace.
- En producción hay que configurar un proveedor de correo (`MAIL_*` en el `.env` del API) y poner en `FRONTEND_URL` la dirección pública del panel web.

## Cuentas de demostración

Todas usan la contraseña `demo-password` (definida en `api/database/seeders/DemoSeeder.php`).

| Correo                   | Rol          | Para probar                                                  |
| ------------------------ | ------------ | ------------------------------------------------------------ |
| `cliente@demo.test`      | customer     | App móvil: restaurantes, carrito, seguimiento de pedidos.    |
| `repartidor@demo.test`   | courier      | App móvil: pedidos disponibles y entregas.                   |
| `restaurante@demo.test`  | restaurant   | Panel web: tablero de pedidos, menú y datos del restaurante. |
| `sushi@demo.test`        | restaurant   | Dueño de un restaurante cerrado (no aparece a los clientes). |
| `admin@demo.test`        | admin        | Panel web: pantalla Cuentas (aprobar, rechazar, suspender).  |
| `repartidor-pendiente@demo.test`  | courier    | App móvil: pantalla "tu cuenta está en revisión".      |
| `restaurante-pendiente@demo.test` | restaurant | Panel web: restaurante en revisión, y la cola del admin. |

Los datos incluyen 7 cuentas, 3 restaurantes con menú y 8 pedidos, uno en cada etapa: pendiente, en preparación, listo, en camino, entregado, cancelado por el restaurante, rechazado y no entregado (estos tres con su motivo). Si corres el planificador, el pedido pendiente se cancelará solo a los 10 minutos.

Para volver a empezar desde cero: `php artisan migrate:fresh --seed` (borra toda la base de datos).

## Pruebas

```bash
cd api && php artisan test                                   # 100 pruebas
cd mobile && flutter test                                    # 41 pruebas
cd mobile/packages/delivery_api_client && dart test          # 9 pruebas
cd mobile/packages/delivery_repository && dart test          # 20 pruebas
cd web && pnpm lint && pnpm build                            # el panel web no tiene pruebas propias
```

Las pruebas del API usan SQLite en memoria: no necesitan PostgreSQL ni Redis.

## API (`/api/v1`)

Autenticación con token (`Authorization: Bearer <token>`). Los precios van en **centavos** enteros.

| Método y ruta                           | Quién            | Qué hace                                              |
| --------------------------------------- | ---------------- | ----------------------------------------------------- |
| `POST /auth/register`                   | público          | Crea la cuenta (cliente, restaurante o repartidor) y devuelve el token. |
| `POST /auth/login`                      | público          | Devuelve el token. Una cuenta suspendida recibe 403.  |
| `POST /auth/forgot-password`            | público          | Envía el correo de recuperación (misma respuesta exista o no la cuenta). |
| `POST /auth/reset-password`             | público          | Cambia la contraseña con el token del correo.         |
| `POST /auth/logout`, `GET /me`          | autenticado      | Cierra sesión / perfil con su estado de cuenta (`status`). |
| `GET /restaurants`, `GET /restaurants/{id}` | público      | Restaurantes abiertos / uno con su menú disponible.   |
| `GET /owner/restaurants`                | restaurant       | Sus restaurantes con todo el menú.                    |
| `POST /restaurants`, `PATCH /restaurants/{id}` | restaurant | Crear y editar (solo el dueño).                     |
| `POST /restaurants/{id}/menu-items`     | restaurant       | Agregar un producto.                                  |
| `PATCH` / `DELETE /menu-items/{id}`     | restaurant       | Editar o eliminar un producto.                        |
| `POST /orders`                          | customer         | Hacer un pedido. El servidor calcula los totales.     |
| `GET /orders`, `GET /orders/{id}`       | cualquiera       | Sus pedidos, según el rol.                            |
| `PATCH /orders/{id}/status`             | según el estado  | Avanza el pedido (el API valida rol y transición). `reason` es obligatorio al rechazar, cancelar (salvo el cliente) o fallar una entrega. |
| `GET /courier/available-orders`         | courier          | Pedidos `ready` sin repartidor.                       |
| `POST /orders/{id}/claim`               | courier          | Tomar un pedido (dos repartidores no pueden tomarlo). |
| `POST /orders/{id}/release`              | courier          | Soltar un pedido que tomó y aún no recogió.           |
| `GET /admin/accounts`                   | admin            | Lista cuentas (`?status=` y `?role=`), con los restaurantes de cada dueño. |
| `PATCH /admin/accounts/{id}/status`     | admin            | `approved` o `suspended` (con `note` opcional). Un admin no puede cambiar a otro admin ni a sí mismo. |

Las cuentas `pending` solo pueden usar `/me`, `/auth/logout` y, si son restaurantes, la gestión de su restaurante y menú. Todo lo demás responde 403 con `code: account_pending`.

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
- **Notificaciones push** ni mapa/seguimiento por GPS del repartidor. Cuando un pedido se cancela solo, el cliente y el restaurante lo ven al refrescar la pantalla (cada 8 a 10 s), pero nadie recibe un aviso.
- **Reembolsos y penalizaciones.** Con pago contra entrega no hay dinero que devolver, pero tampoco hay reglas para un repartidor que suelta pedidos con frecuencia.
- **Traducciones.** Los textos están fijos en español.
- **Correos de producción.** Falta elegir y configurar el proveedor. Tampoco hay correo de verificación al registrarse ni aviso por correo cuando el admin aprueba o rechaza una cuenta.
- **Panel del admin más allá de las cuentas.** No hay reportes, comisiones ni ver pedidos de todos los restaurantes.
- **Varios restaurantes por cuenta en el panel web.** El menú permite elegir entre ellos, pero la pantalla "Restaurante" solo edita el primero y no hay forma de crear uno segundo desde ahí.
- **Repositorio git.** La carpeta aún no está versionada.
