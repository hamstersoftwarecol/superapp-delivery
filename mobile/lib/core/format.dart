import 'package:delivery_repository/delivery_repository.dart';
import 'package:intl/intl.dart';

final _money = NumberFormat.currency(
  locale: 'es_CO',
  symbol: r'$',
  decimalDigits: 0,
  customPattern: '\u00A4#,##0',
);

/// Prices travel as integer cents; this renders them as pesos.
String formatCents(int cents) => _money.format(cents / 100);

/// `14:05` in the device's local time.
String formatTime(DateTime dateTime) {
  final local = dateTime.toLocal();
  final hour = local.hour.toString().padLeft(2, '0');
  final minute = local.minute.toString().padLeft(2, '0');
  return '$hour:$minute';
}

/// A message safe to show to the user for any thrown error.
String errorMessage(Object error) => switch (error) {
  ApiException(:final displayMessage) => displayMessage,
  _ => 'Algo salió mal. Intenta de nuevo.',
};
