import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:superapp_delivery/auth/auth.dart';
import 'package:superapp_delivery/cart/cart.dart';
import 'package:superapp_delivery/home/home.dart';
import 'package:superapp_delivery/orders/orders.dart';
import 'package:superapp_delivery/restaurants/restaurants.dart';

GoRouter buildRouter(AuthCubit authCubit) {
  return GoRouter(
    initialLocation: '/splash',
    refreshListenable: _CubitListenable(authCubit),
    redirect: (context, state) {
      final location = state.matchedLocation;
      final isAuthRoute = location == '/login' || location == '/register';

      return switch (authCubit.state.status) {
        AuthStatus.unknown => location == '/splash' ? null : '/splash',
        AuthStatus.unauthenticated => isAuthRoute ? null : '/login',
        AuthStatus.authenticated =>
          isAuthRoute || location == '/splash' ? '/' : null,
      };
    },
    routes: [
      GoRoute(path: '/splash', builder: (_, _) => const SplashPage()),
      GoRoute(path: '/login', builder: (_, _) => const LoginPage()),
      GoRoute(path: '/register', builder: (_, _) => const RegisterPage()),
      GoRoute(path: '/', builder: (_, _) => const HomePage()),
      GoRoute(
        path: '/restaurants/:id',
        builder: (_, state) => RestaurantDetailPage(
          restaurantId: int.parse(state.pathParameters['id']!),
        ),
      ),
      GoRoute(path: '/cart', builder: (_, _) => const CartPage()),
      GoRoute(
        path: '/orders/:id',
        builder: (_, state) =>
            OrderDetailPage(orderId: int.parse(state.pathParameters['id']!)),
      ),
    ],
  );
}

/// Re-runs the router's redirect whenever the auth state changes.
class _CubitListenable extends ChangeNotifier {
  _CubitListenable(Cubit<dynamic> cubit) {
    _subscription = cubit.stream.listen((_) => notifyListeners());
  }

  late final StreamSubscription<dynamic> _subscription;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}
