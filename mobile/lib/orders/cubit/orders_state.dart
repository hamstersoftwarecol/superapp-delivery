part of 'orders_cubit.dart';

class OrdersState extends Equatable {
  const OrdersState({
    this.status = LoadStatus.initial,
    this.orders = const [],
    this.error,
  });

  final LoadStatus status;
  final List<Order> orders;
  final String? error;

  OrdersState copyWith({
    LoadStatus? status,
    List<Order>? orders,
    String? error,
  }) => OrdersState(
    status: status ?? this.status,
    orders: orders ?? this.orders,
    error: error,
  );

  @override
  List<Object?> get props => [status, orders, error];
}
