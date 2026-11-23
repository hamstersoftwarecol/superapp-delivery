part of 'restaurants_cubit.dart';

class RestaurantsState extends Equatable {
  const RestaurantsState({
    this.status = LoadStatus.initial,
    this.restaurants = const [],
    this.nextCursor,
    this.isLoadingMore = false,
    this.loadMoreFailed = false,
    this.error,
  });

  final LoadStatus status;
  final List<Restaurant> restaurants;

  /// Where the next page starts; `null` when everything has been loaded.
  final String? nextCursor;
  final bool isLoadingMore;
  final bool loadMoreFailed;
  final String? error;

  bool get hasMore => nextCursor != null;

  @override
  List<Object?> get props => [
    status,
    restaurants,
    nextCursor,
    isLoadingMore,
    loadMoreFailed,
    error,
  ];
}
