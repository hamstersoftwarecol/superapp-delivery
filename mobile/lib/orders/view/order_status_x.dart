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
  };

  bool get isProblem =>
      this == OrderStatus.rejected || this == OrderStatus.cancelled;

  Color color(ColorScheme scheme) => switch (this) {
    OrderStatus.delivered => Colors.green.shade700,
    OrderStatus.rejected || OrderStatus.cancelled => scheme.error,
    _ => scheme.primary,
  };
}
