import 'package:delivery_api_client/delivery_api_client.dart';

import 'models/order.dart';

/// Orders for both customers (placing, tracking) and couriers (claiming,
/// delivering). What each role may do is enforced by the API.
class OrderRepository {
  const OrderRepository({required DeliveryApiClient apiClient})
    : _apiClient = apiClient;

  final DeliveryApiClient _apiClient;

  Future<Order> placeOrder({
    required int restaurantId,
    required String deliveryAddress,
    required List<OrderLineRequest> items,
    String? notes,
  }) async {
    final json = await _apiClient.post(
      '/orders',
      body: {
        'restaurant_id': restaurantId,
        'delivery_address': deliveryAddress,
        if (notes != null && notes.isNotEmpty) 'notes': notes,
        'items': [for (final item in items) item.toJson()],
      },
    ) as Map<String, dynamic>;
    return _order(json);
  }

  /// The signed-in user's orders (as customer or as courier), newest first.
  Future<List<Order>> getOrders() async =>
      _orders(await _apiClient.get('/orders'));

  Future<Order> getOrder(int id) async =>
      _order(await _apiClient.get('/orders/$id'));

  Future<Order> updateStatus(int id, OrderStatus status) async => _order(
    await _apiClient.patch(
      '/orders/$id/status',
      body: {'status': status.value},
    ),
  );

  /// Ready orders no courier has taken yet.
  Future<List<Order>> getAvailableOrders() async =>
      _orders(await _apiClient.get('/courier/available-orders'));

  Future<Order> claim(int id) async =>
      _order(await _apiClient.post('/orders/$id/claim'));

  Order _order(Object? json) => Order.fromJson(
    (json as Map<String, dynamic>)['data'] as Map<String, dynamic>,
  );

  List<Order> _orders(Object? json) => [
    for (final item in (json as Map<String, dynamic>)['data'] as List)
      Order.fromJson(item as Map<String, dynamic>),
  ];
}
