import 'package:delivery_repository/delivery_repository.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:superapp_delivery/core/format.dart';
import 'package:superapp_delivery/core/load_status.dart';

part 'restaurants_state.dart';

class RestaurantsCubit extends Cubit<RestaurantsState> {
  RestaurantsCubit({required RestaurantRepository restaurantRepository})
    : _restaurantRepository = restaurantRepository,
      super(const RestaurantsState());

  final RestaurantRepository _restaurantRepository;

  Future<void> load() async {
    emit(state.copyWith(status: LoadStatus.loading));
    try {
      final restaurants = await _restaurantRepository.getRestaurants();
      emit(
        state.copyWith(status: LoadStatus.success, restaurants: restaurants),
      );
    } on Object catch (error) {
      emit(
        state.copyWith(status: LoadStatus.failure, error: errorMessage(error)),
      );
    }
  }
}
