import 'dart:convert';

import 'package:delivery_api_client/delivery_api_client.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';

void main() {
  final baseUrl = Uri.parse('http://api.test/api/v1');

  DeliveryApiClient buildClient(
    MockClientHandler handler, {
    TokenStorage? storage,
  }) => DeliveryApiClient(
    baseUrl: baseUrl,
    tokenStorage: storage ?? InMemoryTokenStorage(),
    httpClient: MockClient(handler),
  );

  http.Response jsonResponse(Object body, [int status = 200]) => http.Response(
    jsonEncode(body),
    status,
    headers: {'content-type': 'application/json'},
  );

  group('requests', () {
    test('sends the bearer token and JSON headers', () async {
      late http.Request seen;
      final client = buildClient((request) async {
        seen = request;
        return jsonResponse({'ok': true});
      }, storage: InMemoryTokenStorage('secret'));

      await client.get('/me');

      expect(seen.url.toString(), 'http://api.test/api/v1/me');
      expect(seen.headers['Authorization'], 'Bearer secret');
      expect(seen.headers['Accept'], 'application/json');
    });

    test('omits the token when the call is not authenticated', () async {
      late http.Request seen;
      final client = buildClient((request) async {
        seen = request;
        return jsonResponse({});
      }, storage: InMemoryTokenStorage('secret'));

      await client.post('/auth/login', body: {'a': 1}, authenticated: false);

      expect(seen.headers.containsKey('Authorization'), isFalse);
      expect(jsonDecode(seen.body), {'a': 1});
    });

    test('returns null for 204 responses', () async {
      final client = buildClient((_) async => http.Response('', 204));

      expect(await client.post('/auth/logout'), isNull);
    });
  });

  group('errors', () {
    test('parses validation errors from a 422', () async {
      final client = buildClient(
        (_) async => jsonResponse({
          'message': 'The given data was invalid.',
          'errors': {
            'email': ['Las credenciales no son correctas.'],
          },
        }, 422),
      );

      await expectLater(
        client.post('/auth/login', authenticated: false),
        throwsA(
          isA<ApiException>()
              .having((e) => e.statusCode, 'statusCode', 422)
              .having(
                (e) => e.displayMessage,
                'displayMessage',
                'Las credenciales no son correctas.',
              ),
        ),
      );
    });

    test('clears the token and signals when the API answers 401', () async {
      final storage = InMemoryTokenStorage('expired');
      final client = buildClient(
        (_) async => jsonResponse({'message': 'Unauthenticated.'}, 401),
        storage: storage,
      );
      final signalled = expectLater(client.unauthorized, emits(anything));

      await expectLater(client.get('/me'), throwsA(isA<ApiException>()));
      await signalled;

      expect(await storage.read(), isNull);
    });

    test('does not treat a 401 without a token as a lost session', () async {
      final client = buildClient(
        (_) async => jsonResponse({'message': 'Unauthenticated.'}, 401),
      );
      var signalled = false;
      client.unauthorized.listen((_) => signalled = true);

      await expectLater(client.get('/me'), throwsA(isA<ApiException>()));
      await Future<void>.delayed(Duration.zero);

      expect(signalled, isFalse);
    });

    test('turns connection failures into a network ApiException', () async {
      final client = buildClient(
        (_) async => throw http.ClientException('no route'),
      );

      await expectLater(
        client.get('/restaurants'),
        throwsA(
          isA<ApiException>().having(
            (e) => e.isNetworkError,
            'isNetworkError',
            true,
          ),
        ),
      );
    });
  });
}
