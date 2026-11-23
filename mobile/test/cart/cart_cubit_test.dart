import 'package:bloc_test/bloc_test.dart';
import 'package:delivery_repository/delivery_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:superapp_delivery/cart/cart.dart';

void main() {
  const tacos = Restaurant(
    id: 1,
    name: 'Tacos',
    address: 'Calle 1',
    deliveryFeeCents: 300000,
    isOpen: true,
  );
  const pizza = Restaurant(
    id: 2,
    name: 'Pizza',
    address: 'Calle 2',
    deliveryFeeCents: 0,
    isOpen: true,
  );
  const taco = MenuItem(
    id: 10,
    restaurantId: 1,
    name: 'Taco',
    priceCents: 450000,
  );
  const soda = MenuItem(
    id: 11,
    restaurantId: 1,
    name: 'Soda',
    priceCents: 200000,
  );
  const margherita = MenuItem(
    id: 20,
    restaurantId: 2,
    name: 'Margherita',
    priceCents: 1800000,
  );

  group('CartCubit', () {
    blocTest<CartCubit, CartState>(
      'adding the same dish twice increases its quantity',
      build: CartCubit.new,
      act: (cubit) => cubit
        ..add(tacos, taco)
        ..add(tacos, taco),
      verify: (cubit) {
        expect(cubit.state.lines, hasLength(1));
        expect(cubit.state.lines.single.quantity, 2);
        expect(cubit.state.subtotalCents, 900000);
        expect(cubit.state.totalCents, 1200000);
      },
    );

    blocTest<CartCubit, CartState>(
      'keeps dishes from several items of the same restaurant',
      build: CartCubit.new,
      act: (cubit) => cubit
        ..add(tacos, taco)
        ..add(tacos, soda),
      verify: (cubit) {
        expect(cubit.state.itemCount, 2);
        expect(cubit.state.restaurantName, 'Tacos');
      },
    );

    blocTest<CartCubit, CartState>(
      'decrementing the last unit empties the cart',
      build: CartCubit.new,
      act: (cubit) => cubit
        ..add(tacos, taco)
        ..decrement(taco.id),
      verify: (cubit) {
        expect(cubit.state.isEmpty, isTrue);
        expect(cubit.state.restaurantId, isNull);
      },
    );

    blocTest<CartCubit, CartState>(
      'adding from another restaurant replaces the cart',
      build: CartCubit.new,
      act: (cubit) => cubit
        ..add(tacos, taco)
        ..add(pizza, margherita),
      verify: (cubit) {
        expect(cubit.state.restaurantId, 2);
        expect(cubit.state.lines.map((line) => line.item.id), [20]);
        expect(cubit.state.deliveryFeeCents, 0);
      },
    );

    test('flags a cart that belongs to another restaurant', () {
      final cubit = CartCubit()..add(tacos, taco);

      expect(cubit.state.belongsToOtherRestaurant(2), isTrue);
      expect(cubit.state.belongsToOtherRestaurant(1), isFalse);
      expect(CartCubit().state.belongsToOtherRestaurant(2), isFalse);
    });
  });
}
