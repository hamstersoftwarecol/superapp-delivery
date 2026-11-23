part of 'available_orders_cubit.dart';

class AvailableOrdersState extends Equatable {
  const AvailableOrdersState({
    this.status = LoadStatus.initial,
    this.orders = const [],
    this.nextCursor,
    this.hasLoadedMore = false,
    this.isLoadingMore = false,
    this.loadMoreFailed = false,
    this.error,
    this.claimingId,
    this.claimError,
  });

  final LoadStatus status;
  final List<Order> orders;

  /// Where the next page starts; `null` when everything has been loaded.
  final String? nextCursor;

  /// Whether the courier scrolled past the first page. The background refresh
  /// pauses then, so the list does not jump under their finger.
  final bool hasLoadedMore;
  final bool isLoadingMore;
  final bool loadMoreFailed;
  final String? error;

  /// The order currently being claimed, if any.
  final int? claimingId;

  final String? claimError;

  bool get hasMore => nextCursor != null;

  AvailableOrdersState copyWith({
    LoadStatus? status,
    List<Order>? orders,
    String? error,
    int? claimingId,
    bool clearClaimingId = false,
    String? claimError,
    bool clearClaimError = false,
  }) => AvailableOrdersState(
    status: status ?? this.status,
    orders: orders ?? this.orders,
    nextCursor: nextCursor,
    hasLoadedMore: hasLoadedMore,
    isLoadingMore: isLoadingMore,
    loadMoreFailed: loadMoreFailed,
    error: error ?? (status == LoadStatus.success ? null : this.error),
    claimingId: clearClaimingId ? null : claimingId ?? this.claimingId,
    claimError: clearClaimError ? null : claimError ?? this.claimError,
  );

  @override
  List<Object?> get props => [
    status,
    orders,
    nextCursor,
    hasLoadedMore,
    isLoadingMore,
    loadMoreFailed,
    error,
    claimingId,
    claimError,
  ];
}
