import 'package:delivery_repository/delivery_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';
import 'package:superapp_delivery/auth/auth.dart';
import 'package:superapp_delivery/cart/cart.dart';
import 'package:superapp_delivery/courier/courier.dart';
import 'package:superapp_delivery/home/view/pending_approval_view.dart';
import 'package:superapp_delivery/orders/orders.dart';
import 'package:superapp_delivery/restaurants/restaurants.dart';

/// Shows the right experience for the signed-in user's role.
class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final user = context.select((AuthCubit cubit) => cubit.state.user);

    return switch (user?.role) {
      UserRole.customer => const _CustomerHome(),
      UserRole.courier when user!.isPending => const PendingApprovalView(),
      UserRole.courier => const _CourierHome(),
      UserRole.restaurant || UserRole.admin || null => const _WebPanelNotice(),
    };
  }
}

class _LogoutButton extends StatelessWidget {
  const _LogoutButton();

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: 'Cerrar sesión',
      icon: const Icon(Icons.logout),
      onPressed: () => context.read<AuthCubit>().logout(),
    );
  }
}

class _CustomerHome extends StatefulWidget {
  const _CustomerHome();

  @override
  State<_CustomerHome> createState() => _CustomerHomeState();
}

class _CustomerHomeState extends State<_CustomerHome> {
  int _index = 0;

  static const _titles = ['Restaurantes', 'Mis pedidos'];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_titles[_index]),
        actions: const [CartButton(), _LogoutButton()],
      ),
      body: IndexedStack(
        index: _index,
        children: const [
          RestaurantsPage(),
          OrdersPage(emptyMessage: 'Aún no has hecho pedidos.'),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (index) => setState(() => _index = index),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.storefront_outlined),
            selectedIcon: Icon(Icons.storefront),
            label: 'Restaurantes',
          ),
          NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long),
            label: 'Mis pedidos',
          ),
        ],
      ),
    );
  }
}

class _CourierHome extends StatefulWidget {
  const _CourierHome();

  @override
  State<_CourierHome> createState() => _CourierHomeState();
}

class _CourierHomeState extends State<_CourierHome> {
  int _index = 0;

  static const _titles = ['Pedidos disponibles', 'Mis entregas'];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_titles[_index]),
        actions: const [_LogoutButton()],
      ),
      body: IndexedStack(
        index: _index,
        children: const [
          AvailableOrdersPage(),
          OrdersPage(emptyMessage: 'Aún no has tomado entregas.'),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (index) => setState(() => _index = index),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.inbox_outlined),
            selectedIcon: Icon(Icons.inbox),
            label: 'Disponibles',
          ),
          NavigationDestination(
            icon: Icon(Icons.two_wheeler_outlined),
            selectedIcon: Icon(Icons.two_wheeler),
            label: 'Mis entregas',
          ),
        ],
      ),
    );
  }
}

class _WebPanelNotice extends StatelessWidget {
  const _WebPanelNotice();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(actions: const [_LogoutButton()]),
      body: const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Text(
            'Los restaurantes y administradores usan el panel web.',
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}
