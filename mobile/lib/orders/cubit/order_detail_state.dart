part of 'order_detail_cubit.dart';

class OrderDetailState extends Equatable {
  const OrderDetailState({
    this.status = LoadStatus.initial,
    this.order,
    this.error,
    this.isUpdating = false,
    this.actionError,
  });

  final LoadStatus status;
  final Order? order;

  /// Why the order could not be loaded.
  final String? error;

  final bool isUpdating;

  /// Why the last status change was refused.
  final String? actionError;

  OrderDetailState copyWith({
    bool? isUpdating,
    String? actionError,
    bool clearActionError = false,
  }) => OrderDetailState(
    status: status,
    order: order,
    error: error,
    isUpdating: isUpdating ?? this.isUpdating,
    actionError: clearActionError ? null : actionError ?? this.actionError,
  );

  @override
  List<Object?> get props => [status, order, error, isUpdating, actionError];
}
