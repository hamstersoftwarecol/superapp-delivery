import 'dart:async';

import 'package:delivery_repository/delivery_repository.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:superapp_delivery/core/format.dart';
import 'package:superapp_delivery/core/load_status.dart';
import 'package:superapp_delivery/core/paging.dart';

part 'orders_state.dart';

/// The signed-in user's orders: placed ones for a customer, assigned ones
/// for a courier. They come newest first, a page at a time, and the newest
/// page refreshes itself while the screen is open.
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
    emit(const OrdersState(status: LoadStatus.loading));
    await _fetch();
    _timer ??= Timer.periodic(_pollInterval, (_) => _fetch(silent: true));
  }

  Future<void> refresh() => _fetch(silent: true);

  /// Fetches the next (older) page, if there is one and none is on its way.
  Future<void> loadMore() async {
    final cursor = state.nextCursor;
    if (cursor == null ||
        state.isLoadingMore ||
        state.status != LoadStatus.success) {
      return;
    }

    emit(_copy(isLoadingMore: true));

    try {
      final page = await _orderRepository.getOrders(cursor: cursor);
      if (isClosed) return;
      emit(
        OrdersState(
          status: LoadStatus.success,
          orders: appendUnique(state.orders, page.items, (order) => order.id),
          nextCursor: page.nextCursor,
          hasLoadedMore: true,
        ),
      );
    } on Object {
      if (isClosed) return;
      emit(_copy(loadMoreFailed: true));
    }
  }

  OrdersState _copy({
    bool isLoadingMore = false,
    bool loadMoreFailed = false,
  }) => OrdersState(
    status: LoadStatus.success,
    orders: state.orders,
    nextCursor: state.nextCursor,
    hasLoadedMore: state.hasLoadedMore,
    isLoadingMore: isLoadingMore,
    loadMoreFailed: loadMoreFailed,
  );

  Future<void> _fetch({bool silent = false}) async {
    try {
      final page = await _orderRepository.getOrders();
      if (isClosed) return;
      emit(
        OrdersState(
          status: LoadStatus.success,
          orders: refreshFirstPage(
            state.orders,
            page.items,
            (order) => order.id,
          ),
          // Once older pages are loaded, their cursor stays as it was.
          nextCursor: state.hasLoadedMore ? state.nextCursor : page.nextCursor,
          hasLoadedMore: state.hasLoadedMore,
          isLoadingMore: state.isLoadingMore,
        ),
      );
    } on Object catch (error) {
      if (isClosed) return;
      // A failed background refresh keeps showing what we already have.
      if (silent && state.status == LoadStatus.success) return;
      emit(
        OrdersState(
          status: LoadStatus.failure,
          orders: state.orders,
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
