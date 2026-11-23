part of 'cart_cubit.dart';

class CartLine extends Equatable {
  const CartLine({required this.item, required this.quantity});

  final MenuItem item;
  final int quantity;

  int get totalCents => item.priceCents * quantity;

  CartLine copyWith({int? quantity}) =>
      CartLine(item: item, quantity: quantity ?? this.quantity);

  @override
  List<Object?> get props => [item, quantity];
}

class CartState extends Equatable {
  const CartState({
    this.restaurantId,
    this.restaurantName,
    this.deliveryFeeCents = 0,
    this.lines = const [],
  });

  final int? restaurantId;
  final String? restaurantName;
  final int deliveryFeeCents;
  final List<CartLine> lines;

  bool get isEmpty => lines.isEmpty;

  int get itemCount => lines.fold(0, (sum, line) => sum + line.quantity);

  int get subtotalCents => lines.fold(0, (sum, line) => sum + line.totalCents);

  int get totalCents => subtotalCents + deliveryFeeCents;

  bool belongsToOtherRestaurant(int id) =>
      restaurantId != null && restaurantId != id && !isEmpty;

  CartState copyWith({
    int? restaurantId,
    String? restaurantName,
    int? deliveryFeeCents,
    List<CartLine>? lines,
  }) => CartState(
    restaurantId: restaurantId ?? this.restaurantId,
    restaurantName: restaurantName ?? this.restaurantName,
    deliveryFeeCents: deliveryFeeCents ?? this.deliveryFeeCents,
    lines: lines ?? this.lines,
  );

  @override
  List<Object?> get props => [
    restaurantId,
    restaurantName,
    deliveryFeeCents,
    lines,
  ];
}
