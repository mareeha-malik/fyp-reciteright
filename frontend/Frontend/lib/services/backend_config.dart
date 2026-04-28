import 'package:flutter/foundation.dart';

/// Shared backend host configuration.
///
/// You can override this at build/run time:
/// flutter run --dart-define=BACKEND_BASE_URL=http://192.168.1.100:8000
class BackendConfig {
  static const String baseUrl = String.fromEnvironment(
    'BACKEND_BASE_URL',
    defaultValue: 'http://192.168.100.7:8000',
  );

  static String compareUrl() =>
      '${baseUrl.replaceAll(RegExp(r'/$'), '')}/api/compare';

  static void debugPrintConfig() {
    if (kDebugMode) {
      // Prints once in debug where services are constructed.
      // Helps diagnose "Failed to load progress" due to wrong host.
      print('Backend base URL: $baseUrl');
    }
  }
}

