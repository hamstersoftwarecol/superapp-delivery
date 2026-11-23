import 'package:delivery_repository/delivery_repository.dart';
import 'package:material_ui/material_ui.dart';

extension OrderStatusX on OrderStatus {
  String get label => switch (this) {
    OrderStatus.pending => 'Esperando confirmación',
    OrderStatus.accepted => 'Aceptado',
    OrderStatus.preparing => 'En preparación',
    OrderStatus.ready => 'Listo para recoger',
    OrderStatus.pickedUp => 'En camino',
    OrderStatus.delivered => 'Entregado',
    OrderStatus.rejected => 'Rechazado por el restaurante',
    OrderStatus.cancelled => 'Cancelado',
    OrderStatus.failed => 'No se pudo entregar',
  };

  bool get isProblem =>
      this == OrderStatus.rejected ||
      this == OrderStatus.cancelled ||
      this == OrderStatus.failed;

  Color color(ColorScheme scheme) => switch (this) {
    OrderStatus.delivered => Colors.green.shade700,
    OrderStatus.rejected ||
    OrderStatus.cancelled ||
    OrderStatus.failed => scheme.error,
    _ => scheme.primary,
  };
}

extension OrderProblemX on Order {
  /// Headline of an order that ended badly, saying who decided.
  String get problemTitle => switch ((status, statusActor)) {
    (OrderStatus.cancelled, OrderActor.customer) => 'Cancelado por el cliente',
    (OrderStatus.cancelled, OrderActor.restaurant) =>
      'Cancelado por el restaurante',
    (OrderStatus.cancelled, OrderActor.system) => 'Cancelado automáticamente',
    (OrderStatus.failed, OrderActor.system) =>
      'No se pudo entregar (cuenta suspendida)',
    _ => status.label,
  };
}
