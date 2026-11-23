import 'dart:async';

import 'package:delivery_repository/delivery_repository.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:superapp_delivery/core/format.dart';
import 'package:superapp_delivery/core/load_status.dart';

part 'order_detail_state.dart';

/// One order, kept fresh until it reaches a final status.
class OrderDetailCubit extends Cubit<OrderDetailState> {
  OrderDetailCubit({
    required OrderRepository orderRepository,
    required int orderId,
    Duration pollInterval = const Duration(seconds: 8),
  }) : _orderRepository = orderRepository,
       _orderId = orderId,
       _pollInterval = pollInterval,
       super(const OrderDetailState());

  final OrderRepository _orderRepository;
  final int _orderId;
  final Duration _pollInterval;
  Timer? _timer;

  Future<void> load() async {
    emit(const OrderDetailState(status: LoadStatus.loading));
    await _fetch();
    _timer ??= Timer.periodic(_pollInterval, (_) => _fetch(silent: true));
  }

  /// Moves the order to [next]; the API decides if the user may do it.
  Future<void> updateStatus(OrderStatus next) async {
    if (state.isUpdating) return;

    emit(state.copyWith(isUpdating: true, clearActionError: true));
    try {
      final order = await _orderRepository.updateStatus(_orderId, next);
      if (isClosed) return;
      emit(OrderDetailState(status: LoadStatus.success, order: order));
    } on Object catch (error) {
      if (isClosed) return;
      emit(state.copyWith(isUpdating: false, actionError: errorMessage(error)));
    }
  }

  Future<void> _fetch({bool silent = false}) async {
    if (state.isUpdating) return;

    try {
      final order = await _orderRepository.getOrder(_orderId);
      if (isClosed) return;
      emit(
        OrderDetailState(
          status: LoadStatus.success,
          order: order,
          actionError: state.actionError,
        ),
      );
      if (order.status.isFinal) _timer?.cancel();
    } on Object catch (error) {
      if (isClosed) return;
      if (silent && state.status == LoadStatus.success) return;
      emit(
        OrderDetailState(
          status: LoadStatus.failure,
          error: errorMessage(error),
        ),
      );
    }
  }

  @override
  Future<void> close() {
    _timer?.cancel();
    return super.close();
  }
}
