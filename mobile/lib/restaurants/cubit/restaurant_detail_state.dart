part of 'restaurant_detail_cubit.dart';

class RestaurantDetailState extends Equatable {
  const RestaurantDetailState({
    this.status = LoadStatus.initial,
    this.restaurant,
    this.error,
  });

  final LoadStatus status;
  final Restaurant? restaurant;
  final String? error;

  @override
  List<Object?> get props => [status, restaurant, error];
}
