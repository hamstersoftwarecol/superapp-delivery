import 'package:delivery_repository/delivery_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:superapp_delivery/cart/cart.dart';
import 'package:superapp_delivery/core/format.dart';
import 'package:superapp_delivery/core/load_status.dart';
import 'package:superapp_delivery/core/widgets/failure_view.dart';
import 'package:superapp_delivery/core/widgets/network_photo.dart';
import 'package:superapp_delivery/restaurants/cubit/restaurant_detail_cubit.dart';

class RestaurantDetailPage extends StatelessWidget {
  const RestaurantDetailPage({required this.restaurantId, super.key});

  final int restaurantId;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => RestaurantDetailCubit(
        restaurantRepository: context.read<RestaurantRepository>(),
        restaurantId: restaurantId,
      )..load(),
      child: const RestaurantDetailView(),
    );
  }
}

class RestaurantDetailView extends StatelessWidget {
  const RestaurantDetailView({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<RestaurantDetailCubit, RestaurantDetailState>(
      builder: (context, state) {
        final restaurant = state.restaurant;

        return Scaffold(
          appBar: AppBar(
            title: Text(restaurant?.name ?? 'Restaurante'),
            actions: const [CartButton()],
          ),
          body: switch (state.status) {
            LoadStatus.failure => FailureView(
              message: state.error ?? 'No se pudo cargar el menú.',
              onRetry: context.read<RestaurantDetailCubit>().load,
            ),
            LoadStatus.success when restaurant != null => _Menu(
              restaurant: restaurant,
            ),
            _ => const Center(child: CircularProgressIndicator()),
          },
          bottomNavigationBar: restaurant == null
              ? null
              : _CartBar(restaurantId: restaurant.id),
        );
      },
    );
  }
}

class _Menu extends StatelessWidget {
  const _Menu({required this.restaurant});

  final Restaurant restaurant;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (restaurant.menuItems.isEmpty) {
      return const Center(
        child: Text('Este restaurante aún no tiene productos.'),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: restaurant.menuItems.length + 1,
      separatorBuilder: (_, _) => const Divider(height: 24),
      itemBuilder: (context, index) {
        if (index == 0) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (restaurant.imageUrl != null) ...[
                AspectRatio(
                  aspectRatio: 3 / 2,
                  child: NetworkPhoto(
                    url: restaurant.imageUrl,
                    semanticLabel: 'Foto de ${restaurant.name}',
                    width: double.infinity,
                  ),
                ),
                const SizedBox(height: 12),
              ],
              Text(
                restaurant.deliveryFeeCents == 0
                    ? 'Envío gratis · ${restaurant.address}'
                    : 'Envío ${formatCents(restaurant.deliveryFeeCents)} · ${restaurant.address}',
                style: theme.textTheme.bodySmall,
              ),
            ],
          );
        }
        final item = restaurant.menuItems[index - 1];
        return _MenuItemTile(restaurant: restaurant, item: item);
      },
    );
  }
}

class _MenuItemTile extends StatelessWidget {
  const _MenuItemTile({required this.restaurant, required this.item});

  final Restaurant restaurant;
  final MenuItem item;

  Future<void> _add(BuildContext context) async {
    final cart = context.read<CartCubit>();

    if (cart.state.belongsToOtherRestaurant(restaurant.id)) {
      final replace = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('¿Empezar un carrito nuevo?'),
          content: Text(
            'Tu carrito tiene productos de ${cart.state.restaurantName}. '
            'Solo puedes pedir a un restaurante a la vez.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(minimumSize: const Size(120, 44)),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Vaciar y empezar'),
            ),
          ],
        ),
      );
      if (replace != true) return;
    }

    cart.add(restaurant, item);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final quantity = context.select(
      (CartCubit cubit) => cubit.state.restaurantId == restaurant.id
          ? cubit.state.lines
                    .where((line) => line.item.id == item.id)
                    .firstOrNull
                    ?.quantity ??
                0
          : 0,
    );

    return Row(
      children: [
        NetworkPhoto(
          url: item.thumbnailUrl,
          semanticLabel: 'Foto de ${item.name}',
          width: 72,
          height: 72,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(item.name, style: theme.textTheme.titleSmall),
              if (item.description != null)
                Text(item.description!, style: theme.textTheme.bodySmall),
              const SizedBox(height: 4),
              Text(
                formatCents(item.priceCents),
                style: theme.textTheme.titleSmall,
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        if (quantity > 0)
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Text('×$quantity', style: theme.textTheme.titleMedium),
          ),
        IconButton.filled(
          tooltip: 'Agregar ${item.name}',
          icon: const Icon(Icons.add),
          onPressed: () => _add(context),
        ),
      ],
    );
  }
}

class _CartBar extends StatelessWidget {
  const _CartBar({required this.restaurantId});

  final int restaurantId;

  @override
  Widget build(BuildContext context) {
    final cart = context.select((CartCubit cubit) => cubit.state);
    if (cart.restaurantId != restaurantId || cart.isEmpty) {
      return const SizedBox.shrink();
    }

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: FilledButton(
          onPressed: () => context.push('/cart'),
          child: Text(
            'Ver carrito (${cart.itemCount}) · ${formatCents(cart.subtotalCents)}',
          ),
        ),
      ),
    );
  }
}
