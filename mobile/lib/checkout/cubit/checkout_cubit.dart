import 'package:delivery_repository/delivery_repository.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:superapp_delivery/core/format.dart';

part 'checkout_state.dart';

class CheckoutCubit extends Cubit<CheckoutState> {
  CheckoutCubit({required OrderRepository orderRepository})
    : _orderRepository = orderRepository,
      super(const CheckoutState());

  final OrderRepository _orderRepository;

  Future<void> submit({
    required int restaurantId,
    required String deliveryAddress,
    required List<OrderLineRequest> items,
    String? notes,
  }) async {
    if (state.status == CheckoutStatus.submitting) return;

    emit(const CheckoutState(status: CheckoutStatus.submitting));
    try {
      final order = await _orderRepository.placeOrder(
        restaurantId: restaurantId,
        deliveryAddress: deliveryAddress,
        items: items,
        notes: notes,
      );
      emit(CheckoutState(status: CheckoutStatus.success, order: order));
    } on Object catch (error) {
      emit(
        CheckoutState(
          status: CheckoutStatus.failure,
          error: errorMessage(error),
        ),
      );
    }
  }
}
