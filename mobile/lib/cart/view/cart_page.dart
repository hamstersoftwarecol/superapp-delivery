import 'package:delivery_repository/delivery_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:superapp_delivery/cart/cubit/cart_cubit.dart';
import 'package:superapp_delivery/checkout/cubit/checkout_cubit.dart';
import 'package:superapp_delivery/core/format.dart';

class CartPage extends StatelessWidget {
  const CartPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) =>
          CheckoutCubit(orderRepository: context.read<OrderRepository>()),
      child: const CartView(),
    );
  }
}

class CartView extends StatefulWidget {
  const CartView({super.key});

  @override
  State<CartView> createState() => _CartViewState();
}

class _CartViewState extends State<CartView> {
  final _formKey = GlobalKey<FormState>();
  final _address = TextEditingController();
  final _notes = TextEditingController();

  @override
  void dispose() {
    _address.dispose();
    _notes.dispose();
    super.dispose();
  }

  void _submit(CartState cart) {
    if (!_formKey.currentState!.validate()) return;

    context.read<CheckoutCubit>().submit(
      restaurantId: cart.restaurantId!,
      deliveryAddress: _address.text.trim(),
      notes: _notes.text.trim(),
      items: [
        for (final line in cart.lines)
          OrderLineRequest(menuItemId: line.item.id, quantity: line.quantity),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<CheckoutCubit, CheckoutState>(
      listener: (context, state) {
        if (state.status == CheckoutStatus.success) {
          final orderId = state.order!.id;
          context.read<CartCubit>().clear();
          context
            ..go('/')
            ..push('/orders/$orderId');
        } else if (state.status == CheckoutStatus.failure) {
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(
              SnackBar(
                content: Text(state.error ?? 'No se pudo hacer el pedido.'),
              ),
            );
        }
      },
      child: Scaffold(
        appBar: AppBar(title: const Text('Tu carrito')),
        body: BlocBuilder<CartCubit, CartState>(
          builder: (context, cart) {
            if (cart.isEmpty) {
              return const Center(child: Text('Tu carrito está vacío.'));
            }
            return _CartContent(
              cart: cart,
              formKey: _formKey,
              address: _address,
              notes: _notes,
              onSubmit: () => _submit(cart),
            );
          },
        ),
      ),
    );
  }
}

class _CartContent extends StatelessWidget {
  const _CartContent({
    required this.cart,
    required this.formKey,
    required this.address,
    required this.notes,
    required this.onSubmit,
  });

  final CartState cart;
  final GlobalKey<FormState> formKey;
  final TextEditingController address;
  final TextEditingController notes;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isSubmitting = context.select(
      (CheckoutCubit cubit) => cubit.state.status == CheckoutStatus.submitting,
    );

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(cart.restaurantName ?? '', style: theme.textTheme.titleMedium),
        const SizedBox(height: 8),
        for (final line in cart.lines) _CartLineTile(line: line),
        const Divider(height: 32),
        _TotalRow(label: 'Subtotal', cents: cart.subtotalCents),
        _TotalRow(label: 'Envío', cents: cart.deliveryFeeCents),
        _TotalRow(label: 'Total', cents: cart.totalCents, emphasized: true),
        const SizedBox(height: 4),
        Text('Pago contra entrega', style: theme.textTheme.bodySmall),
        const SizedBox(height: 24),
        Form(
          key: formKey,
          child: Column(
            children: [
              TextFormField(
                autovalidateMode: AutovalidateMode.onUserInteraction,
                controller: address,
                textCapitalization: TextCapitalization.sentences,
                autofillHints: const [AutofillHints.fullStreetAddress],
                decoration: const InputDecoration(
                  labelText: 'Dirección de entrega',
                  prefixIcon: Icon(Icons.place_outlined),
                ),
                validator: (value) => (value ?? '').trim().isEmpty
                    ? 'Escribe dónde entregamos tu pedido'
                    : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                autovalidateMode: AutovalidateMode.onUserInteraction,
                controller: notes,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Notas para el restaurante (opcional)',
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        FilledButton(
          onPressed: isSubmitting ? null : onSubmit,
          child: isSubmitting
              ? const SizedBox.square(
                  dimension: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text('Hacer pedido · ${formatCents(cart.totalCents)}'),
        ),
      ],
    );
  }
}

class _CartLineTile extends StatelessWidget {
  const _CartLineTile({required this.line});

  final CartLine line;

  @override
  Widget build(BuildContext context) {
    final cart = context.read<CartCubit>();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(line.item.name),
                Text(
                  formatCents(line.totalCents),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Quitar uno de ${line.item.name}',
            icon: const Icon(Icons.remove_circle_outline),
            onPressed: () => cart.decrement(line.item.id),
          ),
          Text('${line.quantity}'),
          IconButton(
            tooltip: 'Agregar uno de ${line.item.name}',
            icon: const Icon(Icons.add_circle_outline),
            onPressed: () => cart.increment(line.item.id),
          ),
        ],
      ),
    );
  }
}

class _TotalRow extends StatelessWidget {
  const _TotalRow({
    required this.label,
    required this.cents,
    this.emphasized = false,
  });

  final String label;
  final int cents;
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
          Text(formatCents(cents), style: style),
        ],
      ),
    );
  }
}
