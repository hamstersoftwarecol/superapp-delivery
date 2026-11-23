import 'package:bloc_test/bloc_test.dart';
import 'package:delivery_repository/delivery_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:superapp_delivery/core/load_status.dart';
import 'package:superapp_delivery/orders/orders.dart';

class _MockOrderRepository extends Mock implements OrderRepository {}

Order _order(int id, [OrderStatus status = OrderStatus.pending]) => Order(
  id: id,
  status: status,
  subtotalCents: 100,
  deliveryFeeCents: 10,
  totalCents: 110,
  deliveryAddress: 'Calle 1',
  createdAt: DateTime(2026, 11, 23),
);

void main() {
  late _MockOrderRepository repository;

  setUp(() => repository = _MockOrderRepository());

  OrdersCubit build() => OrdersCubit(
    orderRepository: repository,
    pollInterval: const Duration(hours: 1),
  );

  group('OrdersCubit', () {
    blocTest<OrdersCubit, OrdersState>(
      'load shows the newest page',
      setUp: () => when(() => repository.getOrders()).thenAnswer(
        (_) async => CursorPage(items: [_order(3), _order(2)], nextCursor: 'c'),
      ),
      build: build,
      act: (cubit) => cubit.load(),
      expect: () => [
        const OrdersState(status: LoadStatus.loading),
        OrdersState(
          status: LoadStatus.success,
          orders: [_order(3), _order(2)],
          nextCursor: 'c',
        ),
      ],
    );

    blocTest<OrdersCubit, OrdersState>(
      'loadMore appends older orders and remembers that the user went further',
      setUp: () =>
          when(() => repository.getOrders(cursor: 'c'))
              .thenAnswer((_) async => CursorPage(items: [_order(1)])),
      build: build,
      seed: () => OrdersState(
        status: LoadStatus.success,
        orders: [_order(3), _order(2)],
        nextCursor: 'c',
      ),
      act: (cubit) => cubit.loadMore(),
      verify: (cubit) {
        expect(cubit.state.orders.map((o) => o.id), [3, 2, 1]);
        expect(cubit.state.hasLoadedMore, isTrue);
        expect(cubit.state.hasMore, isFalse);
      },
    );

    blocTest<OrdersCubit, OrdersState>(
      'a refresh updates the newest orders without losing the older pages',
      setUp: () => when(() => repository.getOrders()).thenAnswer(
        (_) async => CursorPage(
          items: [_order(4), _order(3, OrderStatus.accepted)],
          nextCursor: 'otro',
        ),
      ),
      build: build,
      seed: () => OrdersState(
        status: LoadStatus.success,
        orders: [_order(3), _order(2), _order(1)],
        nextCursor: 'final',
        hasLoadedMore: true,
      ),
      act: (cubit) => cubit.refresh(),
      verify: (cubit) {
        expect(cubit.state.orders.map((o) => o.id), [4, 3, 2, 1]);
        expect(cubit.state.orders[1].status, OrderStatus.accepted);
        expect(
          cubit.state.nextCursor,
          'final',
          reason: 'the cursor of the older pages must not change',
        );
      },
    );

    blocTest<OrdersCubit, OrdersState>(
      'a refresh before scrolling also updates where the next page starts',
      setUp: () => when(() => repository.getOrders()).thenAnswer(
        (_) async =>
            CursorPage(items: [_order(4), _order(3)], nextCursor: 'nuevo'),
      ),
      build: build,
      seed: () => OrdersState(
        status: LoadStatus.success,
        orders: [_order(3)],
        nextCursor: 'viejo',
      ),
      act: (cubit) => cubit.refresh(),
      verify: (cubit) => expect(cubit.state.nextCursor, 'nuevo'),
    );

    blocTest<OrdersCubit, OrdersState>(
      'a failed refresh in the background keeps what is on screen',
      setUp: () =>
          when(() => repository.getOrders())
              .thenThrow(const ApiException(0, 'Sin conexión')),
      build: build,
      seed: () => OrdersState(status: LoadStatus.success, orders: [_order(1)]),
      act: (cubit) => cubit.refresh(),
      expect: () => <OrdersState>[],
    );

    blocTest<OrdersCubit, OrdersState>(
      'a failed loadMore offers a retry and keeps the list',
      setUp: () =>
          when(() => repository.getOrders(cursor: 'c'))
              .thenThrow(const ApiException(0, 'Sin conexión')),
      build: build,
      seed: () => OrdersState(
        status: LoadStatus.success,
        orders: [_order(2)],
        nextCursor: 'c',
      ),
      act: (cubit) => cubit.loadMore(),
      verify: (cubit) {
        expect(cubit.state.loadMoreFailed, isTrue);
        expect(cubit.state.orders, [_order(2)]);
        expect(cubit.state.nextCursor, 'c');
      },
    );
  });
}
