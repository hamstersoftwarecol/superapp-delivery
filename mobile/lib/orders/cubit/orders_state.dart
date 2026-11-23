part of 'orders_cubit.dart';

class OrdersState extends Equatable {
  const OrdersState({
    this.status = LoadStatus.initial,
    this.orders = const [],
    this.nextCursor,
    this.hasLoadedMore = false,
    this.isLoadingMore = false,
    this.loadMoreFailed = false,
    this.error,
  });

  final LoadStatus status;
  final List<Order> orders;

  /// Where the next page starts; `null` when everything has been loaded.
  final String? nextCursor;

  /// Whether the user scrolled past the first page. The background refresh
  /// then leaves [nextCursor] alone so the scroll position stays valid.
  final bool hasLoadedMore;
  final bool isLoadingMore;
  final bool loadMoreFailed;
  final String? error;

  bool get hasMore => nextCursor != null;

  @override
  List<Object?> get props => [
    status,
    orders,
    nextCursor,
    hasLoadedMore,
    isLoadingMore,
    loadMoreFailed,
    error,
  ];
}
