import 'package:delivery_api_client/delivery_api_client.dart';

import 'models/restaurant.dart';

class RestaurantRepository {
  const RestaurantRepository({required DeliveryApiClient apiClient})
    : _apiClient = apiClient;

  final DeliveryApiClient _apiClient;

  /// Restaurants that are currently open.
  Future<List<Restaurant>> getRestaurants() async {
    final json = await _apiClient.get('/restaurants') as Map<String, dynamic>;
    return [
      for (final item in json['data'] as List)
        Restaurant.fromJson(item as Map<String, dynamic>),
    ];
  }

  /// A restaurant with its available menu.
  Future<Restaurant> getRestaurant(int id) async {
    final json =
        await _apiClient.get('/restaurants/$id') as Map<String, dynamic>;
    return Restaurant.fromJson(json['data'] as Map<String, dynamic>);
  }
}
