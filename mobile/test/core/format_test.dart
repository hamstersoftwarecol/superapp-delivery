import 'package:delivery_repository/delivery_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:superapp_delivery/core/format.dart';

void main() {
  group('formatCents', () {
    test('renders cents as pesos with the symbol first', () {
      expect(formatCents(450000), r'$4.500');
      expect(formatCents(1650000), r'$16.500');
      expect(formatCents(0), r'$0');
    });
  });

  group('errorMessage', () {
    test('prefers the first validation message', () {
      const error = ApiException(
        422,
        'The given data was invalid.',
        fieldErrors: {
          'email': ['Las credenciales no son correctas.'],
        },
      );

      expect(errorMessage(error), 'Las credenciales no son correctas.');
    });

    test('hides unexpected errors behind a generic message', () {
      expect(
        errorMessage(StateError('boom')),
        'Algo salió mal. Intenta de nuevo.',
      );
    });
  });
}
