part of 'checkout_cubit.dart';

enum CheckoutStatus { initial, submitting, success, failure }

class CheckoutState extends Equatable {
  const CheckoutState({
    this.status = CheckoutStatus.initial,
    this.order,
    this.error,
  });

  final CheckoutStatus status;
  final Order? order;
  final String? error;

  @override
  List<Object?> get props => [status, order, error];
}
