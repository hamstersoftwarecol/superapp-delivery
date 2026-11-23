import 'package:equatable/equatable.dart';

import 'restaurant.dart';
import 'user.dart';

enum OrderStatus {
  pending('pending'),
  accepted('accepted'),
  preparing('preparing'),
  ready('ready'),
  pickedUp('picked_up'),
  delivered('delivered'),
  rejected('rejected'),
  cancelled('cancelled');

  const OrderStatus(this.value);

  /// The value used by the API.
  final String value;

  static OrderStatus fromJson(String value) =>
      OrderStatus.values.firstWhere((status) => status.value == value);

  /// No further changes are possible.
  bool get isFinal =>
      this == delivered || this == rejected || this == cancelled;
}

class OrderItem extends Equatable {
  const OrderItem({
    required this.id,
    required this.name,
    required this.unitPriceCents,
    required this.quantity,
  });

  factory OrderItem.fromJson(Map<String, dynamic> json) => OrderItem(
    id: json['id'] as int,
    name: json['name'] as String,
    unitPriceCents: json['unit_price_cents'] as int,
    quantity: json['quantity'] as int,
  );

  final int id;
  final String name;
  final int unitPriceCents;
  final int quantity;

  int get totalCents => unitPriceCents * quantity;

  @override
  List<Object?> get props => [id, name, unitPriceCents, quantity];
}

class Order extends Equatable {
  const Order({
    required this.id,
    required this.status,
    required this.subtotalCents,
    required this.deliveryFeeCents,
    required this.totalCents,
    required this.deliveryAddress,
    required this.createdAt,
    this.notes,
    this.restaurant,
    this.customer,
    this.courier,
    this.items = const [],
  });

  factory Order.fromJson(Map<String, dynamic> json) => Order(
    id: json['id'] as int,
    status: OrderStatus.fromJson(json['status'] as String),
    subtotalCents: json['subtotal_cents'] as int,
    deliveryFeeCents: json['delivery_fee_cents'] as int,
    totalCents: json['total_cents'] as int,
    deliveryAddress: json['delivery_address'] as String,
    notes: json['notes'] as String?,
    createdAt: DateTime.parse(json['created_at'] as String),
    restaurant: _optional(json['restaurant'], Restaurant.fromJson),
    customer: _optional(json['customer'], User.fromJson),
    courier: _optional(json['courier'], User.fromJson),
    items: [
      for (final item in (json['items'] as List? ?? const []))
        OrderItem.fromJson(item as Map<String, dynamic>),
    ],
  );

  final int id;
  final OrderStatus status;
  final int subtotalCents;
  final int deliveryFeeCents;
  final int totalCents;
  final String deliveryAddress;
  final String? notes;
  final DateTime createdAt;
  final Restaurant? restaurant;
  final User? customer;
  final User? courier;
  final List<OrderItem> items;

  @override
  List<Object?> get props => [
    id,
    status,
    subtotalCents,
    deliveryFeeCents,
    totalCents,
    deliveryAddress,
    notes,
    createdAt,
    restaurant,
    customer,
    courier,
    items,
  ];
}

T? _optional<T>(Object? json, T Function(Map<String, dynamic>) fromJson) =>
    json is Map<String, dynamic> ? fromJson(json) : null;

/// One line of an order being placed: which dish and how many.
class OrderLineRequest extends Equatable {
  const OrderLineRequest({required this.menuItemId, required this.quantity});

  final int menuItemId;
  final int quantity;

  Map<String, Object> toJson() => {
    'menu_item_id': menuItemId,
    'quantity': quantity,
  };

  @override
  List<Object?> get props => [menuItemId, quantity];
}
