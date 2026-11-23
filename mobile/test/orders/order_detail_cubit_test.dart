import 'package:bloc_test/bloc_test.dart';
import 'package:delivery_repository/delivery_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:superapp_delivery/core/load_status.dart';
import 'package:superapp_delivery/orders/orders.dart';

class _MockOrderRepository extends Mock implements OrderRepository {}

Order _order(OrderStatus status) => Order(
  id: 5,
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

  OrderDetailCubit build() => OrderDetailCubit(
    orderRepository: repository,
    orderId: 5,
    pollInterval: const Duration(hours: 1),
  );

  group('OrderDetailCubit', () {
    blocTest<OrderDetailCubit, OrderDetailState>(
      'load emits loading then the order',
      setUp: () =>
          when(() => repository.getOrder(5))
              .thenAnswer((_) async => _order(OrderStatus.preparing)),
      build: build,
      act: (cubit) => cubit.load(),
      expect: () => [
        const OrderDetailState(status: LoadStatus.loading),
        OrderDetailState(
          status: LoadStatus.success,
          order: _order(OrderStatus.preparing),
        ),
      ],
    );

    blocTest<OrderDetailCubit, OrderDetailState>(
      'load reports a failure with the API message',
      setUp: () =>
          when(() => repository.getOrder(5))
              .thenThrow(const ApiException(404, 'No existe')),
      build: build,
      act: (cubit) => cubit.load(),
      expect: () => [
        const OrderDetailState(status: LoadStatus.loading),
        const OrderDetailState(status: LoadStatus.failure, error: 'No existe'),
      ],
    );

    blocTest<OrderDetailCubit, OrderDetailState>(
      'updateStatus shows the progress and replaces the order',
      setUp: () =>
          when(() => repository.updateStatus(5, OrderStatus.delivered))
              .thenAnswer((_) async => _order(OrderStatus.delivered)),
      build: build,
      act: (cubit) => cubit.updateStatus(OrderStatus.delivered),
      expect: () => [
        const OrderDetailState(isUpdating: true),
        OrderDetailState(
          status: LoadStatus.success,
          order: _order(OrderStatus.delivered),
        ),
      ],
    );

    blocTest<OrderDetailCubit, OrderDetailState>(
      'updateStatus keeps the order and exposes the refusal',
      seed: () => OrderDetailState(
        status: LoadStatus.success,
        order: _order(OrderStatus.ready),
      ),
      setUp: () =>
          when(() => repository.updateStatus(5, OrderStatus.pickedUp))
              .thenThrow(const ApiException(403, 'No autorizado')),
      build: build,
      act: (cubit) => cubit.updateStatus(OrderStatus.pickedUp),
      expect: () => [
        OrderDetailState(
          status: LoadStatus.success,
          order: _order(OrderStatus.ready),
          isUpdating: true,
        ),
        OrderDetailState(
          status: LoadStatus.success,
          order: _order(OrderStatus.ready),
          actionError: 'No autorizado',
        ),
      ],
    );
  });
}
