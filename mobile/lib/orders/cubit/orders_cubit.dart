import 'dart:async';

import 'package:delivery_repository/delivery_repository.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:superapp_delivery/core/format.dart';
import 'package:superapp_delivery/core/load_status.dart';

part 'orders_state.dart';

/// The signed-in user's orders: placed ones for a customer, assigned ones
/// for a courier. Refreshes itself while the screen is open.
class OrdersCubit extends Cubit<OrdersState> {
  OrdersCubit({
    required OrderRepository orderRepository,
    Duration pollInterval = const Duration(seconds: 10),
  }) : _orderRepository = orderRepository,
       _pollInterval = pollInterval,
       super(const OrdersState());

  final OrderRepository _orderRepository;
  final Duration _pollInterval;
  Timer? _timer;

  Future<void> load() async {
    emit(state.copyWith(status: LoadStatus.loading));
    await _fetch();
    _timer ??= Timer.periodic(_pollInterval, (_) => _fetch(silent: true));
  }

  Future<void> refresh() => _fetch(silent: true);

  Future<void> _fetch({bool silent = false}) async {
    try {
      final orders = await _orderRepository.getOrders();
      if (isClosed) return;
      emit(OrdersState(status: LoadStatus.success, orders: orders));
    } on Object catch (error) {
      if (isClosed) return;
      // A failed background refresh keeps showing what we already have.
      if (silent && state.status == LoadStatus.success) return;
      emit(
        state.copyWith(status: LoadStatus.failure, error: errorMessage(error)),
      );
    }
  }

  @override
  Future<void> close() {
    _timer?.cancel();
    return super.close();
  }
}
