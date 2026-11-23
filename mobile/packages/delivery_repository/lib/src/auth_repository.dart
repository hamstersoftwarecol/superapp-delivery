import 'dart:async';

import 'package:delivery_api_client/delivery_api_client.dart';

import 'models/user.dart';

/// Sign-in state and session lifecycle.
class AuthRepository {
  AuthRepository({
    required DeliveryApiClient apiClient,
    required TokenStorage tokenStorage,
  }) : _apiClient = apiClient,
       _tokenStorage = tokenStorage {
    _unauthorizedSubscription = _apiClient.unauthorized.listen(
      (_) => _userController.add(null),
    );
  }

  final DeliveryApiClient _apiClient;
  final TokenStorage _tokenStorage;
  final _userController = StreamController<User?>.broadcast();
  late final StreamSubscription<void> _unauthorizedSubscription;

  /// Emits the signed-in user, or `null` when the session ends.
  Stream<User?> get user => _userController.stream;

  /// Restores a previous session. Returns `null` if there is none or it
  /// is no longer valid. Throws [ApiException] on network errors so the
  /// caller can tell "signed out" apart from "offline".
  Future<User?> restoreSession() async {
    if (await _tokenStorage.read() == null) return null;

    try {
      final json = await _apiClient.get('/me') as Map<String, dynamic>;
      return User.fromJson(json['data'] as Map<String, dynamic>);
    } on ApiException catch (error) {
      if (error.statusCode == 401) return null;
      rethrow;
    }
  }

  /// Re-reads the signed-in user, e.g. to learn that an admin approved the
  /// account, and emits the fresh data on [user].
  Future<User> refreshUser() async {
    final json = await _apiClient.get('/me') as Map<String, dynamic>;
    final user = User.fromJson(json['data'] as Map<String, dynamic>);
    _userController.add(user);
    return user;
  }

  /// Asks the server to email a password reset link. The answer is the same
  /// whether or not the address has an account, so it reveals nothing.
  Future<String> forgotPassword({required String email}) async {
    final json = await _apiClient.post(
      '/auth/forgot-password',
      body: {'email': email},
      authenticated: false,
    ) as Map<String, dynamic>;
    return json['message'] as String;
  }

  Future<User> login({required String email, required String password}) =>
      _authenticate('/auth/login', {
        'email': email,
        'password': password,
        'device_name': 'mobile',
      });

  Future<User> register({
    required String name,
    required String email,
    required String password,
    required UserRole role,
    String? phone,
  }) => _authenticate('/auth/register', {
    'name': name,
    'email': email,
    'password': password,
    'role': role.name,
    if (phone != null && phone.isNotEmpty) 'phone': phone,
  });

  Future<void> logout() async {
    try {
      await _apiClient.post('/auth/logout');
    } on ApiException {
      // The local session ends regardless of what the server says.
    }
    await _tokenStorage.clear();
    _userController.add(null);
  }

  Future<User> _authenticate(String path, Map<String, Object> body) async {
    final json = await _apiClient.post(
      path,
      body: body,
      authenticated: false,
    ) as Map<String, dynamic>;
    await _tokenStorage.write(json['token'] as String);
    final user = User.fromJson(json['user'] as Map<String, dynamic>);
    _userController.add(user);
    return user;
  }

  Future<void> dispose() async {
    await _unauthorizedSubscription.cancel();
    await _userController.close();
  }
}
