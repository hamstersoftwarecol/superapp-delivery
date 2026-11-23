import 'package:delivery_repository/delivery_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';
import 'package:superapp_delivery/auth/auth.dart';
import 'package:superapp_delivery/core/format.dart';
import 'package:superapp_delivery/core/load_status.dart';
import 'package:superapp_delivery/core/widgets/failure_view.dart';
import 'package:superapp_delivery/orders/cubit/order_detail_cubit.dart';
import 'package:superapp_delivery/orders/view/order_status_x.dart';

class OrderDetailPage extends StatelessWidget {
  const OrderDetailPage({required this.orderId, super.key});

  final int orderId;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => OrderDetailCubit(
        orderRepository: context.read<OrderRepository>(),
        orderId: orderId,
      )..load(),
      child: const OrderDetailView(),
    );
  }
}

class OrderDetailView extends StatelessWidget {
  const OrderDetailView({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<OrderDetailCubit, OrderDetailState>(
      listenWhen: (a, b) =>
          a.actionError != b.actionError && b.actionError != null,
      listener: (context, state) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(state.actionError!)));
      },
      builder: (context, state) {
        final order = state.order;

        return Scaffold(
          appBar: AppBar(
            title: Text(order == null ? 'Pedido' : 'Pedido #${order.id}'),
          ),
          body: switch (state.status) {
            LoadStatus.failure => FailureView(
              message: state.error ?? 'No se pudo cargar el pedido.',
              onRetry: context.read<OrderDetailCubit>().load,
            ),
            LoadStatus.success when order != null => _OrderBody(order: order),
            _ => const Center(child: CircularProgressIndicator()),
          },
          bottomNavigationBar: order == null
              ? null
              : _Actions(order: order, isUpdating: state.isUpdating),
        );
      },
    );
  }
}

class _OrderBody extends StatelessWidget {
  const _OrderBody({required this.order});

  final Order order;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final role = context.select((AuthCubit cubit) => cubit.state.user?.role);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _StatusTracker(status: order.status),
        const SizedBox(height: 24),
        Text(order.restaurant?.name ?? '', style: theme.textTheme.titleMedium),
        if (order.restaurant != null)
          Text(order.restaurant!.address, style: theme.textTheme.bodySmall),
        const SizedBox(height: 16),
        for (final item in order.items)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(child: Text('${item.quantity} × ${item.name}')),
                Text(formatCents(item.totalCents)),
              ],
            ),
          ),
        const Divider(height: 24),
        _Row(label: 'Subtotal', value: formatCents(order.subtotalCents)),
        _Row(label: 'Envío', value: formatCents(order.deliveryFeeCents)),
        _Row(
          label: 'Total',
          value: formatCents(order.totalCents),
          emphasized: true,
        ),
        Text('Pago contra entrega', style: theme.textTheme.bodySmall),
        const SizedBox(height: 24),
        _InfoTile(
          icon: Icons.place_outlined,
          title: 'Entregar en',
          text: order.deliveryAddress,
        ),
        if (order.notes != null)
          _InfoTile(icon: Icons.notes, title: 'Notas', text: order.notes!),
        if (role == UserRole.courier && order.customer != null)
          _InfoTile(
            icon: Icons.person_outline,
            title: 'Cliente',
            text: [order.customer!.name, ?order.customer!.phone].join(' · '),
          ),
        if (role == UserRole.customer && order.courier != null)
          _InfoTile(
            icon: Icons.two_wheeler,
            title: 'Repartidor',
            text: order.courier!.name,
          ),
      ],
    );
  }
}

class _StatusTracker extends StatelessWidget {
  const _StatusTracker({required this.status});

  final OrderStatus status;

  static const _steps = [
    OrderStatus.pending,
    OrderStatus.accepted,
    OrderStatus.preparing,
    OrderStatus.ready,
    OrderStatus.pickedUp,
    OrderStatus.delivered,
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (status.isProblem) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: theme.colorScheme.errorContainer,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(
              Icons.cancel_outlined,
              color: theme.colorScheme.onErrorContainer,
            ),
            const SizedBox(width: 12),
            Text(
              status.label,
              style: theme.textTheme.titleSmall?.copyWith(
                color: theme.colorScheme.onErrorContainer,
              ),
            ),
          ],
        ),
      );
    }

    final current = _steps.indexOf(status);

    return Semantics(
      label: 'Estado del pedido: ${status.label}',
      child: Column(
        children: [
          for (final (index, step) in _steps.indexed)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Icon(
                    index < current
                        ? Icons.check_circle
                        : index == current
                        ? Icons.radio_button_checked
                        : Icons.radio_button_unchecked,
                    color: index <= current
                        ? theme.colorScheme.primary
                        : theme.colorScheme.outline,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    step.label,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: index == current
                          ? FontWeight.w700
                          : FontWeight.w400,
                      color: index > current ? theme.colorScheme.outline : null,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.label,
    required this.value,
    this.emphasized = false,
  });

  final String label;
  final String value;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final style = emphasized
        ? Theme.of(context).textTheme.titleMedium
        : Theme.of(context).textTheme.bodyMedium;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: style),
          Text(value, style: style),
        ],
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  const _InfoTile({
    required this.icon,
    required this.title,
    required this.text,
  });

  final IconData icon;
  final String title;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: theme.colorScheme.outline),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: theme.textTheme.labelMedium),
                Text(text),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The one thing the current user can do next with this order, if anything.
class _Actions extends StatelessWidget {
  const _Actions({required this.order, required this.isUpdating});

  final Order order;
  final bool isUpdating;

  @override
  Widget build(BuildContext context) {
    final user = context.select((AuthCubit cubit) => cubit.state.user);
    final cubit = context.read<OrderDetailCubit>();

    final isCustomer = user?.role == UserRole.customer;
    final isAssignedCourier =
        user?.role == UserRole.courier && order.courier?.id == user?.id;

    final Widget? button;
    if (isCustomer && order.status == OrderStatus.pending) {
      button = OutlinedButton(
        onPressed: isUpdating ? null : () => _confirmCancel(context, cubit),
        child: const Text('Cancelar pedido'),
      );
    } else if (isAssignedCourier && order.status == OrderStatus.ready) {
      button = FilledButton(
        onPressed: isUpdating
            ? null
            : () => cubit.updateStatus(OrderStatus.pickedUp),
        child: const Text('Recogí el pedido'),
      );
    } else if (isAssignedCourier && order.status == OrderStatus.pickedUp) {
      button = FilledButton(
        onPressed: isUpdating
            ? null
            : () => cubit.updateStatus(OrderStatus.delivered),
        child: const Text('Marcar como entregado'),
      );
    } else {
      button = null;
    }

    if (button == null) return const SizedBox.shrink();

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: button,
      ),
    );
  }

  Future<void> _confirmCancel(
    BuildContext context,
    OrderDetailCubit cubit,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('¿Cancelar el pedido?'),
        content: const Text('Esta acción no se puede deshacer.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Volver'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size(120, 44)),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Sí, cancelar'),
          ),
        ],
      ),
    );
    if (confirmed == true) await cubit.updateStatus(OrderStatus.cancelled);
  }
}
