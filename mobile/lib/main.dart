import 'package:delivery_api_client/delivery_api_client.dart';
import 'package:delivery_repository/delivery_repository.dart';
import 'package:material_ui/material_ui.dart';
import 'package:superapp_delivery/app/app.dart';
import 'package:superapp_delivery/core/api_config.dart';
import 'package:superapp_delivery/core/secure_token_storage.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // Data layer
  final tokenStorage = SecureTokenStorage();
  final apiClient = DeliveryApiClient(
    baseUrl: resolveApiBaseUrl(),
    tokenStorage: tokenStorage,
  );

  // Repository layer
  runApp(
    App(
      authRepository: AuthRepository(
        apiClient: apiClient,
        tokenStorage: tokenStorage,
      ),
      restaurantRepository: RestaurantRepository(apiClient: apiClient),
      orderRepository: OrderRepository(apiClient: apiClient),
    ),
  );
}
