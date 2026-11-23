import 'package:delivery_repository/delivery_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:superapp_delivery/orders/view/order_status_x.dart';

Order _order(OrderStatus status, [OrderActor? actor]) => Order(
  id: 1,
  status: status,
  subtotalCents: 100,
  deliveryFeeCents: 10,
  totalCents: 110,
  deliveryAddress: 'Calle 1',
  createdAt: DateTime(2026, 11, 23),
  statusActor: actor,
);

void main() {
  group('problem headline', () {
    test('says who cancelled', () {
      expect(
        _order(OrderStatus.cancelled, OrderActor.customer).problemTitle,
        'Cancelado por el cliente',
      );
      expect(
        _order(OrderStatus.cancelled, OrderActor.restaurant).problemTitle,
        'Cancelado por el restaurante',
      );
      expect(
        _order(OrderStatus.cancelled, OrderActor.system).problemTitle,
        'Cancelado automáticamente',
      );
    });

    test('falls back to the plain status when nobody is recorded', () {
      expect(_order(OrderStatus.cancelled).problemTitle, 'Cancelado');
      expect(
        _order(OrderStatus.rejected, OrderActor.restaurant).problemTitle,
        'Rechazado por el restaurante',
      );
      expect(
        _order(OrderStatus.failed, OrderActor.courier).problemTitle,
        'No se pudo entregar',
      );
    });

    test('every ending that is not a delivery counts as a problem', () {
      for (final status in [
        OrderStatus.rejected,
        OrderStatus.cancelled,
        OrderStatus.failed,
      ]) {
        expect(status.isProblem, isTrue, reason: status.name);
      }
      expect(OrderStatus.delivered.isProblem, isFalse);
    });
  });
}
