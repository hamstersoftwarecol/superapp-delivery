import 'package:delivery_repository/delivery_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:superapp_delivery/core/format.dart';
import 'package:superapp_delivery/core/load_status.dart';
import 'package:superapp_delivery/core/widgets/failure_view.dart';
import 'package:superapp_delivery/core/widgets/load_more.dart';
import 'package:superapp_delivery/courier/cubit/available_orders_cubit.dart';

class AvailableOrdersPage extends StatelessWidget {
  const AvailableOrdersPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) =>
          AvailableOrdersCubit(orderRepository: context.read<OrderRepository>())
            ..load(),
      child: const AvailableOrdersView(),
    );
  }
}

class AvailableOrdersView extends StatelessWidget {
  const AvailableOrdersView({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<AvailableOrdersCubit, AvailableOrdersState>(
      listenWhen: (a, b) =>
          a.claimError != b.claimError && b.claimError != null,
      listener: (context, state) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(state.claimError!)));
      },
      builder: (context, state) {
        final cubit = context.read<AvailableOrdersCubit>();

        if (state.status == LoadStatus.failure) {
          return FailureView(
            message: state.error ?? 'No se pudieron cargar los pedidos.',
            onRetry: cubit.load,
          );
        }
        if (state.status != LoadStatus.success) {
          return const Center(child: CircularProgressIndicator());
        }

        return RefreshIndicator(
          onRefresh: cubit.refresh,
          child: state.orders.isEmpty
              ? ListView(
                  children: const [
                    SizedBox(height: 120),
                    Center(child: Text('No hay pedidos listos por ahora.')),
                  ],
                )
              : LoadMoreListener(
                  onEnd: cubit.loadMore,
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: state.orders.length + 1,
                    separatorBuilder: (_, _) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      if (index == state.orders.length) {
                        return PagingFooter(
                          isLoading: state.isLoadingMore,
                          failed: state.loadMoreFailed,
                          onRetry: cubit.loadMore,
                        );
                      }
                      final order = state.orders[index];
                      return _AvailableOrderCard(
                        order: order,
                        isClaiming: state.claimingId == order.id,
                        isBusy: state.claimingId != null,
                      );
                    },
                  ),
                ),
        );
      },
    );
  }
}

class _AvailableOrderCard extends StatelessWidget {
  const _AvailableOrderCard({
    required this.order,
    required this.isClaiming,
    required this.isBusy,
  });

  final Order order;
  final bool isClaiming;
  final bool isBusy;

  Future<void> _claim(BuildContext context) async {
    final router = GoRouter.of(context);
    final claimed = await context.read<AvailableOrdersCubit>().claim(order.id);
    if (claimed != null) await router.push('/orders/${claimed.id}');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              order.restaurant?.name ?? 'Pedido #${order.id}',
              style: theme.textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            _Line(
              icon: Icons.storefront_outlined,
              text: order.restaurant?.address ?? '',
            ),
            _Line(icon: Icons.place_outlined, text: order.deliveryAddress),
            const SizedBox(height: 4),
            Text(
              'Envío ${formatCents(order.deliveryFeeCents)} · Total ${formatCents(order.totalCents)}',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: isBusy ? null : () => _claim(context),
              child: isClaiming
                  ? const SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Tomar pedido'),
            ),
          ],
        ),
      ),
    );
  }
}

class _Line extends StatelessWidget {
  const _Line({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: theme.colorScheme.outline),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: theme.textTheme.bodySmall)),
        ],
      ),
    );
  }
}
