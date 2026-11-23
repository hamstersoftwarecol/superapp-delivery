/// Error returned by the API (or raised when it cannot be reached).
///
/// A [statusCode] of `0` means the request never got a response
/// (no connection, timeout).
class ApiException implements Exception {
  const ApiException(
    this.statusCode,
    this.message, {
    this.fieldErrors = const {},
  });

  final int statusCode;
  final String message;

  /// Validation errors keyed by field name (HTTP 422).
  final Map<String, List<String>> fieldErrors;

  bool get isNetworkError => statusCode == 0;

  /// The first validation message, falling back to [message].
  String get displayMessage {
    for (final messages in fieldErrors.values) {
      if (messages.isNotEmpty) return messages.first;
    }
    return message;
  }

  @override
  String toString() => 'ApiException($statusCode): $message';
}
