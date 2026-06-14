import 'package:flutter/foundation.dart';

/// Shared backend host configuration.
class BackendConfig {
  static const String baseUrl = String.fromEnvironment(
    'BACKEND_BASE_URL',
    // CHANGE THIS LINE BELOW:
    defaultValue: 'https://fyp-reciteright.onrender.com',
  );

  static String compareUrl() =>
      '${baseUrl.replaceAll(RegExp(r'/$'), '')}/api/compare';

  static void debugPrintConfig() {
    if (kDebugMode) {
      print('Backend base URL: $baseUrl');
    }
  }
}