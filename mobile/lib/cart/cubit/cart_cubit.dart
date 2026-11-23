import 'package:delivery_repository/delivery_repository.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

part 'cart_state.dart';

/// The customer's basket. It only ever holds dishes from one restaurant.
class CartCubit extends Cubit<CartState> {
  CartCubit() : super(const CartState());

  /// Adds one unit of [item]. If the cart belongs to a different
  /// restaurant it is replaced, so ask the user first
  /// (see [CartState.belongsToOtherRestaurant]).
  void add(Restaurant restaurant, MenuItem item) {
    final base = state.belongsToOtherRestaurant(restaurant.id)
        ? CartState(
            restaurantId: restaurant.id,
            restaurantName: restaurant.name,
            deliveryFeeCents: restaurant.deliveryFeeCents,
          )
        : state.copyWith(
            restaurantId: restaurant.id,
            restaurantName: restaurant.name,
            deliveryFeeCents: restaurant.deliveryFeeCents,
          );

    final index = base.lines.indexWhere((line) => line.item.id == item.id);
    final lines = [...base.lines];
    if (index == -1) {
      lines.add(CartLine(item: item, quantity: 1));
    } else {
      lines[index] = lines[index].copyWith(quantity: lines[index].quantity + 1);
    }
    emit(base.copyWith(lines: lines));
  }

  void increment(int menuItemId) => _change(menuItemId, 1);

  void decrement(int menuItemId) => _change(menuItemId, -1);

  void clear() => emit(const CartState());

  void _change(int menuItemId, int delta) {
    final lines = <CartLine>[];
    for (final line in state.lines) {
      if (line.item.id != menuItemId) {
        lines.add(line);
        continue;
      }
      final quantity = line.quantity + delta;
      if (quantity > 0) lines.add(line.copyWith(quantity: quantity));
    }

    if (lines.isEmpty) {
      clear();
    } else {
      emit(state.copyWith(lines: lines));
    }
  }
}
