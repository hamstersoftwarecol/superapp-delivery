import 'package:delivery_repository/delivery_repository.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:superapp_delivery/core/format.dart';
import 'package:superapp_delivery/core/load_status.dart';
import 'package:superapp_delivery/core/paging.dart';

part 'restaurants_state.dart';

class RestaurantsCubit extends Cubit<RestaurantsState> {
  RestaurantsCubit({required RestaurantRepository restaurantRepository})
    : _restaurantRepository = restaurantRepository,
      super(const RestaurantsState());

  final RestaurantRepository _restaurantRepository;

  /// Loads the first page again, forgetting any further pages.
  Future<void> load() async {
    emit(const RestaurantsState(status: LoadStatus.loading));
    try {
      final page = await _restaurantRepository.getRestaurants();
      emit(
        RestaurantsState(
          status: LoadStatus.success,
          restaurants: page.items,
          nextCursor: page.nextCursor,
        ),
      );
    } on Object catch (error) {
      emit(
        RestaurantsState(
          status: LoadStatus.failure,
          error: errorMessage(error),
        ),
      );
    }
  }

  /// Fetches the next page, if there is one and none is already on its way.
  Future<void> loadMore() async {
    final cursor = state.nextCursor;
    if (cursor == null ||
        state.isLoadingMore ||
        state.status != LoadStatus.success) {
      return;
    }

    emit(
      RestaurantsState(
        status: LoadStatus.success,
        restaurants: state.restaurants,
        nextCursor: cursor,
        isLoadingMore: true,
      ),
    );

    try {
      final page = await _restaurantRepository.getRestaurants(cursor: cursor);
      if (isClosed) return;
      emit(
        RestaurantsState(
          status: LoadStatus.success,
          restaurants: appendUnique(
            state.restaurants,
            page.items,
            (restaurant) => restaurant.id,
          ),
          nextCursor: page.nextCursor,
        ),
      );
    } on Object {
      if (isClosed) return;
      emit(
        RestaurantsState(
          status: LoadStatus.success,
          restaurants: state.restaurants,
          nextCursor: cursor,
          loadMoreFailed: true,
        ),
      );
    }
  }
}
