import 'package:delivery_repository/delivery_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:superapp_delivery/app/router.dart';
import 'package:superapp_delivery/app/theme.dart';
import 'package:superapp_delivery/auth/auth.dart';
import 'package:superapp_delivery/cart/cart.dart';

class App extends StatefulWidget {
  const App({
    required this.authRepository,
    required this.restaurantRepository,
    required this.orderRepository,
    super.key,
  });

  final AuthRepository authRepository;
  final RestaurantRepository restaurantRepository;
  final OrderRepository orderRepository;

  @override
  State<App> createState() => _AppState();
}

class _AppState extends State<App> {
  late final AuthCubit _authCubit;
  late final GoRouter _router;

  @override
  void initState() {
    super.initState();
    _authCubit = AuthCubit(authRepository: widget.authRepository)..started();
    _router = buildRouter(_authCubit);
  }

  @override
  void dispose() {
    _router.dispose();
    _authCubit.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider.value(value: widget.authRepository),
        RepositoryProvider.value(value: widget.restaurantRepository),
        RepositoryProvider.value(value: widget.orderRepository),
      ],
      child: MultiBlocProvider(
        providers: [
          BlocProvider.value(value: _authCubit),
          BlocProvider(create: (_) => CartCubit()),
        ],
        child: MaterialApp.router(
          title: 'SuperApp Delivery',
          debugShowCheckedModeBanner: false,
          theme: buildTheme(Brightness.light),
          darkTheme: buildTheme(Brightness.dark),
          routerConfig: _router,
        ),
      ),
    );
  }
}
