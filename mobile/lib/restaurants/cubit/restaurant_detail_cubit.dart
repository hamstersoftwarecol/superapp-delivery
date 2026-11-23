import 'package:delivery_repository/delivery_repository.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:superapp_delivery/core/format.dart';
import 'package:superapp_delivery/core/load_status.dart';

part 'restaurant_detail_state.dart';

class RestaurantDetailCubit extends Cubit<RestaurantDetailState> {
  RestaurantDetailCubit({
    required RestaurantRepository restaurantRepository,
    required int restaurantId,
  }) : _restaurantRepository = restaurantRepository,
       _restaurantId = restaurantId,
       super(const RestaurantDetailState());

  final RestaurantRepository _restaurantRepository;
  final int _restaurantId;

  Future<void> load() async {
    emit(const RestaurantDetailState(status: LoadStatus.loading));
    try {
      final restaurant = await _restaurantRepository.getRestaurant(
        _restaurantId,
      );
      emit(
        RestaurantDetailState(
          status: LoadStatus.success,
          restaurant: restaurant,
        ),
      );
    } on Object catch (error) {
      emit(
        RestaurantDetailState(
          status: LoadStatus.failure,
          error: errorMessage(error),
        ),
      );
    }
  }
}
