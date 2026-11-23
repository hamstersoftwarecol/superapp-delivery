part of 'available_orders_cubit.dart';

class AvailableOrdersState extends Equatable {
  const AvailableOrdersState({
    this.status = LoadStatus.initial,
    this.orders = const [],
    this.error,
    this.claimingId,
    this.claimError,
  });

  final LoadStatus status;
  final List<Order> orders;
  final String? error;

  /// The order currently being claimed, if any.
  final int? claimingId;

  final String? claimError;

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
    error: error ?? (status == LoadStatus.success ? null : this.error),
    claimingId: clearClaimingId ? null : claimingId ?? this.claimingId,
    claimError: clearClaimError ? null : claimError ?? this.claimError,
  );

  @override
  List<Object?> get props => [status, orders, error, claimingId, claimError];
}
