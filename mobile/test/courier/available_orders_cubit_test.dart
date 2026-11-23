import 'package:bloc_test/bloc_test.dart';
import 'package:delivery_repository/delivery_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:superapp_delivery/core/load_status.dart';
import 'package:superapp_delivery/courier/courier.dart';

class _MockOrderRepository extends Mock implements OrderRepository {}

Order _order(int id) => Order(
  id: id,
  status: OrderStatus.ready,
  subtotalCents: 100,
  deliveryFeeCents: 10,
  totalCents: 110,
  deliveryAddress: 'Calle 1',
  createdAt: DateTime(2026, 11, 23),
);

void main() {
  late _MockOrderRepository repository;

  setUp(() => repository = _MockOrderRepository());

  AvailableOrdersCubit build() => AvailableOrdersCubit(
    orderRepository: repository,
    pollInterval: const Duration(hours: 1),
  );

  group('AvailableOrdersCubit', () {
    blocTest<AvailableOrdersCubit, AvailableOrdersState>(
      'loadMore appends the next page',
      setUp: () =>
          when(() => repository.getAvailableOrders(cursor: 'c'))
              .thenAnswer((_) async => CursorPage(items: [_order(21)])),
      build: build,
      seed: () => AvailableOrdersState(
        status: LoadStatus.success,
        orders: [_order(1), _order(2)],
        nextCursor: 'c',
      ),
      act: (cubit) => cubit.loadMore(),
      verify: (cubit) {
        expect(cubit.state.orders.map((o) => o.id), [1, 2, 21]);
        expect(cubit.state.hasLoadedMore, isTrue);
        expect(cubit.state.hasMore, isFalse);
      },
    );

    test('the background refresh stays out of the way while the courier browses further pages', () async {
      when(() => repository.getAvailableOrders()).thenAnswer(
        (_) async => CursorPage(items: [_order(1), _order(2)], nextCursor: 'c'),
      );
      when(() => repository.getAvailableOrders(cursor: 'c'))
          .thenAnswer((_) async => CursorPage(items: [_order(21)]));
      final cubit = AvailableOrdersCubit(
        orderRepository: repository,
        pollInterval: const Duration(milliseconds: 20),
      );
      addTearDown(cubit.close);

      await cubit.load();
      await cubit.loadMore();
      expect(cubit.state.orders.map((o) => o.id), [1, 2, 21]);

      // Several refresh ticks go by...
      await Future<void>.delayed(const Duration(milliseconds: 120));

      // ...and none of them replaced the list the courier is scrolling.
      expect(cubit.state.orders.map((o) => o.id), [1, 2, 21]);
      verify(() => repository.getAvailableOrders()).called(1);
    });

    test(
      'the background refresh does reload the list while on the first page',
      () async {
        var calls = 0;
        when(() => repository.getAvailableOrders()).thenAnswer((_) async {
          calls++;
          return CursorPage(items: [_order(calls)]);
        });
        final cubit = AvailableOrdersCubit(
          orderRepository: repository,
          pollInterval: const Duration(milliseconds: 20),
        );
        addTearDown(cubit.close);

        await cubit.load();
        await Future<void>.delayed(const Duration(milliseconds: 100));

        expect(calls, greaterThan(1));
        expect(cubit.state.orders.single.id, calls);
      },
    );

    blocTest<AvailableOrdersCubit, AvailableOrdersState>(
      'pulling to refresh starts again from the first page',
      setUp: () =>
          when(() => repository.getAvailableOrders())
              .thenAnswer((_) async => CursorPage(items: [_order(7)])),
      build: build,
      seed: () => AvailableOrdersState(
        status: LoadStatus.success,
        orders: [_order(1), _order(21)],
        nextCursor: 'c',
        hasLoadedMore: true,
      ),
      act: (cubit) => cubit.refresh(),
      verify: (cubit) {
        expect(cubit.state.orders.map((o) => o.id), [7]);
        expect(cubit.state.hasLoadedMore, isFalse);
      },
    );

    blocTest<AvailableOrdersCubit, AvailableOrdersState>(
      'a claimed order leaves the list at once, without reloading every page',
      setUp: () =>
          when(() => repository.claim(2)).thenAnswer((_) async => _order(2)),
      build: build,
      seed: () => AvailableOrdersState(
        status: LoadStatus.success,
        orders: [_order(1), _order(2), _order(21)],
        nextCursor: 'c',
        hasLoadedMore: true,
      ),
      act: (cubit) async {
        expect((await cubit.claim(2))?.id, 2);
      },
      verify: (cubit) {
        expect(cubit.state.orders.map((o) => o.id), [1, 21]);
        verifyNever(
          () => repository.getAvailableOrders(cursor: any(named: 'cursor')),
        );
      },
    );

    blocTest<AvailableOrdersCubit, AvailableOrdersState>(
      'an order someone else took disappears and the courier is told',
      setUp: () {
        when(() => repository.claim(1))
            .thenThrow(const ApiException(409, 'Ya lo tomaron'));
        when(() => repository.getAvailableOrders())
            .thenAnswer((_) async => CursorPage(items: [_order(2)]));
      },
      build: build,
      seed: () => AvailableOrdersState(
        status: LoadStatus.success,
        orders: [_order(1), _order(2)],
      ),
      act: (cubit) async {
        expect(await cubit.claim(1), isNull);
      },
      verify: (cubit) {
        expect(cubit.state.claimError, 'Ya lo tomaron');
        expect(cubit.state.orders.map((o) => o.id), [2]);
      },
    );
  });
}
