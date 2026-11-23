import 'package:delivery_api_client/delivery_api_client.dart';

import 'models/cursor_page.dart';
import 'models/restaurant.dart';

class RestaurantRepository {
  const RestaurantRepository({required DeliveryApiClient apiClient})
    : _apiClient = apiClient;

  final DeliveryApiClient _apiClient;

  /// One page of the restaurants that are open. Pass the previous page's
  /// [CursorPage.nextCursor] as [cursor] to get the following one.
  Future<CursorPage<Restaurant>> getRestaurants({String? cursor}) async {
    final json = await _apiClient.get(
      '/restaurants',
      query: {'cursor': ?cursor},
    ) as Map<String, dynamic>;
    return CursorPage.fromJson(json, Restaurant.fromJson);
  }

  /// A restaurant with its available menu.
  Future<Restaurant> getRestaurant(int id) async {
    final json =
        await _apiClient.get('/restaurants/$id') as Map<String, dynamic>;
    return Restaurant.fromJson(json['data'] as Map<String, dynamic>);
  }
}
