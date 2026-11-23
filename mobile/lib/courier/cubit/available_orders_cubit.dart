import 'dart:async';

import 'package:delivery_repository/delivery_repository.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:superapp_delivery/core/format.dart';
import 'package:superapp_delivery/core/load_status.dart';
import 'package:superapp_delivery/core/paging.dart';

part 'available_orders_state.dart';

/// Ready orders waiting for a courier, oldest first, a page at a time.
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
    emit(const AvailableOrdersState(status: LoadStatus.loading));
    await _fetch();
    _timer ??= Timer.periodic(_pollInterval, (_) => _fetch(silent: true));
  }

  Future<void> refresh() => _fetch(silent: true, force: true);

  /// Fetches the next page, if there is one and none is already on its way.
  Future<void> loadMore() async {
    final cursor = state.nextCursor;
    if (cursor == null ||
        state.isLoadingMore ||
        state.status != LoadStatus.success) {
      return;
    }

    emit(_paging(isLoadingMore: true));

    try {
      final page = await _orderRepository.getAvailableOrders(cursor: cursor);
      if (isClosed) return;
      emit(
        AvailableOrdersState(
          status: LoadStatus.success,
          orders: appendUnique(state.orders, page.items, (order) => order.id),
          nextCursor: page.nextCursor,
          hasLoadedMore: true,
          claimingId: state.claimingId,
          claimError: state.claimError,
        ),
      );
    } on Object {
      if (isClosed) return;
      emit(_paging(loadMoreFailed: true));
    }
  }

  /// Takes the order. Returns it on success, or `null` if someone else was
  /// faster (the error is then in [AvailableOrdersState.claimError]).
  Future<Order?> claim(int orderId) async {
    if (state.claimingId != null) return null;

    emit(state.copyWith(claimingId: orderId, clearClaimError: true));
    try {
      final order = await _orderRepository.claim(orderId);
      if (isClosed) return order;
      emit(_without(orderId).copyWith(clearClaimingId: true));
      return order;
    } on Object catch (error) {
      if (isClosed) return null;
      // Most likely someone took it first, so it no longer belongs on the list.
      emit(
        _without(orderId)
            .copyWith(clearClaimingId: true, claimError: errorMessage(error)),
      );
      await _fetch(silent: true);
      return null;
    }
  }

  AvailableOrdersState _paging({
    bool isLoadingMore = false,
    bool loadMoreFailed = false,
  }) => AvailableOrdersState(
    status: LoadStatus.success,
    orders: state.orders,
    nextCursor: state.nextCursor,
    hasLoadedMore: state.hasLoadedMore,
    isLoadingMore: isLoadingMore,
    loadMoreFailed: loadMoreFailed,
    claimingId: state.claimingId,
    claimError: state.claimError,
  );

  AvailableOrdersState _without(int orderId) => AvailableOrdersState(
    status: state.status,
    orders: [
      for (final order in state.orders)
        if (order.id != orderId) order,
    ],
    nextCursor: state.nextCursor,
    hasLoadedMore: state.hasLoadedMore,
    isLoadingMore: state.isLoadingMore,
    loadMoreFailed: state.loadMoreFailed,
    claimingId: state.claimingId,
    claimError: state.claimError,
  );

  /// Reloads the first page. While the courier is browsing further pages the
  /// background refresh stays out of the way; pulling to refresh does not.
  Future<void> _fetch({bool silent = false, bool force = false}) async {
    if (state.hasLoadedMore && !force) return;

    try {
      final page = await _orderRepository.getAvailableOrders();
      if (isClosed) return;
      emit(
        AvailableOrdersState(
          status: LoadStatus.success,
          orders: page.items,
          nextCursor: page.nextCursor,
          claimingId: state.claimingId,
          claimError: state.claimError,
        ),
      );
    } on Object catch (error) {
      if (isClosed) return;
      if (silent && state.status == LoadStatus.success) return;
      emit(
        AvailableOrdersState(
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
