import 'dart:async';

import 'package:delivery_repository/delivery_repository.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:superapp_delivery/core/format.dart';
import 'package:superapp_delivery/core/load_status.dart';

part 'available_orders_state.dart';

/// Ready orders waiting for a courier.
class AvailableOrdersCubit extends Cubit<AvailableOrdersState> {
  AvailableOrdersCubit({
    required OrderRepository orderRepository,
    Duration pollInterval = const Duration(seconds: 8),
  }) : _orderRepository = orderRepository,
       _pollInterval = pollInterval,
       super(const AvailableOrdersState());

  final OrderRepository _orderRepository;
  final Duration _pollInterval;
  Timer? _timer;

  Future<void> load() async {
    emit(state.copyWith(status: LoadStatus.loading));
    await _fetch();
    _timer ??= Timer.periodic(_pollInterval, (_) => _fetch(silent: true));
  }

  Future<void> refresh() => _fetch(silent: true);

  /// Takes the order. Returns it on success, or `null` if someone else was
  /// faster (the error is then in [AvailableOrdersState.claimError]).
  Future<Order?> claim(int orderId) async {
    if (state.claimingId != null) return null;

    emit(state.copyWith(claimingId: orderId, clearClaimError: true));
    try {
      final order = await _orderRepository.claim(orderId);
      if (isClosed) return order;
      emit(state.copyWith(clearClaimingId: true));
      await _fetch(silent: true);
      return order;
    } on Object catch (error) {
      if (isClosed) return null;
      emit(
        state.copyWith(clearClaimingId: true, claimError: errorMessage(error)),
      );
      await _fetch(silent: true);
      return null;
    }
  }

  Future<void> _fetch({bool silent = false}) async {
    try {
      final orders = await _orderRepository.getAvailableOrders();
      if (isClosed) return;
      emit(state.copyWith(status: LoadStatus.success, orders: orders));
    } on Object catch (error) {
      if (isClosed) return;
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
