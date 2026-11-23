import 'dart:io' show Platform;

const _apiUrlOverride = String.fromEnvironment('API_URL');

/// Base URL of the Laravel API.
///
/// Override with `--dart-define=API_URL=https://...` (needed on a physical
/// phone, where `localhost` is the phone itself). By default it points to
/// the host machine: `10.0.2.2` is how the Android emulator reaches it.
Uri resolveApiBaseUrl() {
  if (_apiUrlOverride.isNotEmpty) return Uri.parse(_apiUrlOverride);

  final host = Platform.isAndroid ? '10.0.2.2' : 'localhost';
  return Uri.parse('http://$host:8000/api/v1');
}
