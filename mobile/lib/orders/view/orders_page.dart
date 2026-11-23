import 'package:delivery_repository/delivery_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:superapp_delivery/core/format.dart';
import 'package:superapp_delivery/core/load_status.dart';
import 'package:superapp_delivery/core/widgets/failure_view.dart';
import 'package:superapp_delivery/core/widgets/load_more.dart';
import 'package:superapp_delivery/orders/cubit/orders_cubit.dart';
import 'package:superapp_delivery/orders/view/order_status_x.dart';

class OrdersPage extends StatelessWidget {
  const OrdersPage({required this.emptyMessage, super.key});

  final String emptyMessage;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) =>
          OrdersCubit(orderRepository: context.read<OrderRepository>())..load(),
      child: OrdersView(emptyMessage: emptyMessage),
    );
  }
}

class OrdersView extends StatelessWidget {
  const OrdersView({required this.emptyMessage, super.key});

  final String emptyMessage;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<OrdersCubit, OrdersState>(
      builder: (context, state) {
        final cubit = context.read<OrdersCubit>();

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
                  children: [
                    const SizedBox(height: 120),
                    Center(child: Text(emptyMessage)),
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
                      return OrderCard(order: state.orders[index]);
                    },
                  ),
                ),
        );
      },
    );
  }
}

class OrderCard extends StatelessWidget {
  const OrderCard({required this.order, super.key});

  final Order order;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push('/orders/${order.id}'),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Pedido #${order.id} · ${order.restaurant?.name ?? ''}',
                      style: theme.textTheme.titleSmall,
                    ),
                  ),
                  Text(
                    formatTime(order.createdAt),
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                order.status.label,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: order.status.color(theme.colorScheme),
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${order.items.fold<int>(0, (sum, item) => sum + item.quantity)} productos · '
                '${formatCents(order.totalCents)}',
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
