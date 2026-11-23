import 'dart:convert';

import 'package:delivery_api_client/delivery_api_client.dart';
import 'package:delivery_repository/delivery_repository.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';

const _userJson = {
  'id': 7,
  'name': 'Ana',
  'email': 'ana@example.test',
  'phone': null,
  'role': 'customer',
};

const _orderJson = {
  'id': 3,
  'status': 'picked_up',
  'subtotal_cents': 1350000,
  'delivery_fee_cents': 300000,
  'total_cents': 1650000,
  'delivery_address': 'Carrera 7 # 40-10',
  'notes': null,
  'payment_method': 'cash',
  'created_at': '2026-11-23T19:31:00.000000Z',
  'items': [
    {
      'id': 1,
      'menu_item_id': 9,
      'name': 'Taco al pastor',
      'unit_price_cents': 450000,
      'quantity': 3,
    },
  ],
};

/// Like a real server: the body is UTF-8 bytes, so accents survive.
http.Response _json(Object body, [int status = 200]) => http.Response.bytes(
  utf8.encode(jsonEncode(body)),
  status,
  headers: {'content-type': 'application/json'},
);

void main() {
  late InMemoryTokenStorage storage;

  DeliveryApiClient buildClient(MockClientHandler handler) => DeliveryApiClient(
    baseUrl: Uri.parse('http://api.test/api/v1'),
    tokenStorage: storage,
    httpClient: MockClient(handler),
  );

  setUp(() => storage = InMemoryTokenStorage());

  group('AuthRepository', () {
    test('login stores the token and emits the user', () async {
      final repository = AuthRepository(
        apiClient: buildClient(
          (_) async => _json({'token': 'abc', 'user': _userJson}),
        ),
        tokenStorage: storage,
      );
      final emitted = expectLater(repository.user, emits(isA<User>()));

      final user = await repository.login(
        email: 'ana@example.test',
        password: 'x',
      );

      expect(user.role, UserRole.customer);
      expect(await storage.read(), 'abc');
      await emitted;
    });

    test('restoreSession returns null without a stored token', () async {
      final repository = AuthRepository(
        apiClient: buildClient((_) async => fail('should not call the API')),
        tokenStorage: storage,
      );

      expect(await repository.restoreSession(), isNull);
    });

    test('restoreSession returns null when the token was rejected', () async {
      await storage.write('old');
      final repository = AuthRepository(
        apiClient: buildClient((_) async => _json({'message': 'x'}, 401)),
        tokenStorage: storage,
      );

      expect(await repository.restoreSession(), isNull);
      expect(await storage.read(), isNull);
    });

    test(
      'restoreSession rethrows when offline so the token survives',
      () async {
        await storage.write('keep');
        final repository = AuthRepository(
          apiClient: buildClient(
            (_) async => throw http.ClientException('offline'),
          ),
          tokenStorage: storage,
        );

        await expectLater(
          repository.restoreSession(),
          throwsA(isA<ApiException>()),
        );
        expect(await storage.read(), 'keep');
      },
    );

    test('forgotPassword asks for the email without sending a token', () async {
      await storage.write('stale');
      late http.Request seen;
      final repository = AuthRepository(
        apiClient: buildClient((request) async {
          seen = request;
          return _json({'message': 'Revisa tu correo'});
        }),
        tokenStorage: storage,
      );

      final message = await repository.forgotPassword(
        email: 'ana@example.test',
      );

      expect(message, 'Revisa tu correo');
      expect(seen.url.path, '/api/v1/auth/forgot-password');
      expect(seen.headers.containsKey('Authorization'), isFalse);
      expect(jsonDecode(seen.body), {'email': 'ana@example.test'});
    });

    test('refreshUser emits the account with its new status', () async {
      await storage.write('abc');
      final repository = AuthRepository(
        apiClient: buildClient(
          (_) async => _json({
            'data': {..._userJson, 'role': 'courier', 'status': 'approved'},
          }),
        ),
        tokenStorage: storage,
      );
      final emitted = expectLater(
        repository.user,
        emits(
          isA<User>().having((u) => u.status, 'status', AccountStatus.approved),
        ),
      );

      final user = await repository.refreshUser();

      expect(user.role, UserRole.courier);
      await emitted;
    });

    test('logout clears the token even if the server call fails', () async {
      await storage.write('abc');
      final repository = AuthRepository(
        apiClient: buildClient(
          (_) async => throw http.ClientException('offline'),
        ),
        tokenStorage: storage,
      );

      await repository.logout();

      expect(await storage.read(), isNull);
    });
  });

  group('OrderRepository', () {
    test('placeOrder sends the lines and maps the order', () async {
      late http.Request seen;
      final repository = OrderRepository(
        apiClient: buildClient((request) async {
          seen = request;
          return _json({'data': _orderJson}, 201);
        }),
      );

      final order = await repository.placeOrder(
        restaurantId: 1,
        deliveryAddress: 'Carrera 7 # 40-10',
        items: const [OrderLineRequest(menuItemId: 9, quantity: 3)],
      );

      expect(jsonDecode(seen.body), {
        'restaurant_id': 1,
        'delivery_address': 'Carrera 7 # 40-10',
        'items': [
          {'menu_item_id': 9, 'quantity': 3},
        ],
      });
      expect(order.status, OrderStatus.pickedUp);
      expect(order.items.single.totalCents, 1350000);
      expect(order.courier, isNull);
    });

    test('updateStatus sends the API value of the status', () async {
      late http.Request seen;
      final repository = OrderRepository(
        apiClient: buildClient((request) async {
          seen = request;
          return _json({'data': _orderJson});
        }),
      );

      await repository.updateStatus(3, OrderStatus.pickedUp);

      expect(seen.method, 'PATCH');
      expect(seen.url.path, '/api/v1/orders/3/status');
      expect(jsonDecode(seen.body), {'status': 'picked_up'});
    });

    test('updateStatus sends the reason when the order ends badly', () async {
      late http.Request seen;
      final repository = OrderRepository(
        apiClient: buildClient((request) async {
          seen = request;
          return _json({'data': _orderJson});
        }),
      );

      await repository.updateStatus(
        3,
        OrderStatus.failed,
        reason: 'El cliente no contestó',
      );

      expect(jsonDecode(seen.body), {
        'status': 'failed',
        'reason': 'El cliente no contestó',
      });
    });

    test('updateStatus leaves the reason out when there is none', () async {
      late http.Request seen;
      final repository = OrderRepository(
        apiClient: buildClient((request) async {
          seen = request;
          return _json({'data': _orderJson});
        }),
      );

      await repository.updateStatus(3, OrderStatus.accepted);

      expect(jsonDecode(seen.body), {'status': 'accepted'});
    });

    test('release gives the order back through its own endpoint', () async {
      late http.Request seen;
      final repository = OrderRepository(
        apiClient: buildClient((request) async {
          seen = request;
          return _json({'data': _orderJson});
        }),
      );

      await repository.release(3);

      expect(seen.method, 'POST');
      expect(seen.url.path, '/api/v1/orders/3/release');
    });

    test('maps who decided and why an order ended badly', () async {
      final repository = OrderRepository(
        apiClient: buildClient(
          (_) async => _json({
            'data': {
              ..._orderJson,
              'status': 'cancelled',
              'status_reason': 'El restaurante no respondió a tiempo.',
              'status_actor': 'system',
            },
          }),
        ),
      );

      final order = await repository.getOrder(3);

      expect(order.status, OrderStatus.cancelled);
      expect(order.statusActor, OrderActor.system);
      expect(order.statusReason, 'El restaurante no respondió a tiempo.');
    });

    test('getAvailableOrders maps the list', () async {
      final repository = OrderRepository(
        apiClient: buildClient(
          (_) async => _json({
            'data': [_orderJson, _orderJson],
          }),
        ),
      );

      expect(await repository.getAvailableOrders(), hasLength(2));
    });
  });

  group('RestaurantRepository', () {
    test('getRestaurant maps the menu', () async {
      final repository = RestaurantRepository(
        apiClient: buildClient(
          (_) async => _json({
            'data': {
              'id': 1,
              'name': 'Tacos Don Pepe',
              'description': null,
              'address': 'Calle 10',
              'delivery_fee_cents': 300000,
              'is_open': true,
              'menu_items': [
                {
                  'id': 9,
                  'restaurant_id': 1,
                  'name': 'Taco',
                  'description': null,
                  'price_cents': 450000,
                  'is_available': true,
                },
              ],
            },
          }),
        ),
      );

      final restaurant = await repository.getRestaurant(1);

      expect(restaurant.menuItems.single.name, 'Taco');
      expect(restaurant.deliveryFeeCents, 300000);
    });
  });

  group('User', () {
    test('reads the review status of the account', () {
      for (final status in AccountStatus.values) {
        final user = User.fromJson({..._userJson, 'status': status.name});
        expect(user.status, status);
      }
      expect(
        User.fromJson({..._userJson, 'status': 'pending'}).isPending,
        isTrue,
      );
    });

    test('treats a missing status as approved (older servers)', () {
      expect(User.fromJson(_userJson).status, AccountStatus.approved);
    });

    test('knows the admin role', () {
      expect(UserRole.fromJson('admin'), UserRole.admin);
    });
  });

  group('OrderStatus', () {
    test('round-trips every API value', () {
      for (final status in OrderStatus.values) {
        expect(OrderStatus.fromJson(status.value), status);
      }
    });

    test('knows which statuses are final', () {
      expect(OrderStatus.delivered.isFinal, isTrue);
      expect(OrderStatus.cancelled.isFinal, isTrue);
      expect(OrderStatus.failed.isFinal, isTrue);
      expect(OrderStatus.pickedUp.isFinal, isFalse);
      expect(OrderStatus.ready.isFinal, isFalse);
    });
  });
}
