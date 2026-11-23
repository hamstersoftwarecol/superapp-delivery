import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:superapp_delivery/cart/cubit/cart_cubit.dart';

/// App bar action that opens the cart, with the item count as a badge.
class CartButton extends StatelessWidget {
  const CartButton({super.key});

  @override
  Widget build(BuildContext context) {
    final count = context.select((CartCubit cubit) => cubit.state.itemCount);

    return IconButton(
      tooltip: count == 0 ? 'Carrito' : 'Carrito, $count productos',
      onPressed: () => context.push('/cart'),
      icon: Badge(
        isLabelVisible: count > 0,
        label: Text('$count'),
        child: const Icon(Icons.shopping_cart_outlined),
      ),
    );
  }
}
