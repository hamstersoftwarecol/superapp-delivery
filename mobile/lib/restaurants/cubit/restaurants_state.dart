part of 'restaurants_cubit.dart';

class RestaurantsState extends Equatable {
  const RestaurantsState({
    this.status = LoadStatus.initial,
    this.restaurants = const [],
    this.error,
  });

  final LoadStatus status;
  final List<Restaurant> restaurants;
  final String? error;

  RestaurantsState copyWith({
    LoadStatus? status,
    List<Restaurant>? restaurants,
    String? error,
  }) => RestaurantsState(
    status: status ?? this.status,
    restaurants: restaurants ?? this.restaurants,
    error: error,
  );

  @override
  List<Object?> get props => [status, restaurants, error];
}
