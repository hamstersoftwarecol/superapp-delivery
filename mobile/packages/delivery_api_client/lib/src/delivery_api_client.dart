import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'api_exception.dart';
import 'token_storage.dart';

/// Thin JSON-over-HTTP client for the SuperApp Delivery API.
///
/// It adds the bearer token, decodes responses and turns failures into
/// [ApiException]s. It knows nothing about the domain.
class DeliveryApiClient {
  DeliveryApiClient({
    required Uri baseUrl,
    required TokenStorage tokenStorage,
    http.Client? httpClient,
    Duration timeout = const Duration(seconds: 15),
  }) : _baseUrl = baseUrl,
       _tokenStorage = tokenStorage,
       _httpClient = httpClient ?? http.Client(),
       _timeout = timeout;

  final Uri _baseUrl;
  final TokenStorage _tokenStorage;
  final http.Client _httpClient;
  final Duration _timeout;
  final _unauthorized = StreamController<void>.broadcast();

  /// Emits when the API rejects the stored token (it expired or was revoked).
  /// The token has already been cleared when this fires.
  Stream<void> get unauthorized => _unauthorized.stream;

  Future<Object?> get(String path, {Map<String, String>? query}) =>
      _send('GET', path, query: query);

  Future<Object?> post(
    String path, {
    Object? body,
    bool authenticated = true,
  }) => _send('POST', path, body: body, authenticated: authenticated);

  Future<Object?> patch(String path, {Object? body}) =>
      _send('PATCH', path, body: body);

  Future<Object?> _send(
    String method,
    String path, {
    Map<String, String>? query,
    Object? body,
    bool authenticated = true,
  }) async {
    final token = authenticated ? await _tokenStorage.read() : null;
    final uri = _baseUrl.replace(
      path: '${_baseUrl.path}$path',
      queryParameters: query,
    );

    final request = http.Request(method, uri)
      ..headers['Accept'] = 'application/json';
    if (token != null) request.headers['Authorization'] = 'Bearer $token';
    if (body != null) {
      request.headers['Content-Type'] = 'application/json';
      request.body = jsonEncode(body);
    }

    final http.Response response;
    try {
      final streamed = await _httpClient.send(request).timeout(_timeout);
      response = await http.Response.fromStream(streamed);
    } on TimeoutException {
      throw const ApiException(0, 'El servidor tardó demasiado en responder.');
    } on http.ClientException {
      throw const ApiException(
        0,
        'No se pudo conectar con el servidor. Revisa tu conexión.',
      );
    }

    if (response.statusCode == 204 || response.body.isEmpty) {
      return _throwIfFailed(response, token, null);
    }

    Object? decoded;
    try {
      decoded = jsonDecode(utf8.decode(response.bodyBytes));
    } on FormatException {
      decoded = null;
    }
    return _throwIfFailed(response, token, decoded);
  }

  Future<Object?> _throwIfFailed(
    http.Response response,
    String? token,
    Object? decoded,
  ) async {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return decoded;
    }

    if (response.statusCode == 401 && token != null) {
      await _tokenStorage.clear();
      _unauthorized.add(null);
    }

    final json = decoded is Map<String, dynamic> ? decoded : const {};
    throw ApiException(
      response.statusCode,
      json['message'] as String? ?? 'Ocurrió un error inesperado.',
      fieldErrors: _parseFieldErrors(json['errors']),
    );
  }

  Map<String, List<String>> _parseFieldErrors(Object? errors) {
    if (errors is! Map) return const {};
    return {
      for (final entry in errors.entries)
        entry.key.toString(): [
          for (final message in (entry.value as List? ?? const []))
            message.toString(),
        ],
    };
  }

  void dispose() {
    _unauthorized.close();
    _httpClient.close();
  }
}
