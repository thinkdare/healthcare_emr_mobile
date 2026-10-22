import 'dart:io';
import 'package:flutter/foundation.dart';

class AppConfig {
  /// Throws in any non-debug build when [url] is not https. This replaces an
  /// assert(), which Dart strips from release builds and so enforced nothing.
  static void _requireHttpsOutsideDebug(String url) {
    if (!kDebugMode && !url.startsWith('https://')) {
      throw StateError('Production build must use HTTPS. Got: $url');
    }
  }

  static void _requireExplicitUrlOutsideDebug(String define) {
    if (!kDebugMode) {
      throw StateError(
        '$define must be set via --dart-define in non-debug builds.',
      );
    }
  }

  /// Port of the backend dev stack (NGINX_PORT). Only used by the debug fallbacks below.
  static const String _devPort = '8180';

  static const String appName = 'Healthcare EMR System';
  static const String apiVersion = 'v1';

  static String get baseUrl {
    const fromEnv = String.fromEnvironment('API_BASE_URL');
    if (fromEnv.isNotEmpty) {
      _requireHttpsOutsideDebug(fromEnv);
      return fromEnv;
    }
    // Dev fallback only: a non-debug build must be given an explicit https URL.
    _requireExplicitUrlOutsideDebug('API_BASE_URL');
    // The backend's nginx listens on NGINX_PORT (8180 in its .env.example). The stock
    // Android emulator reaches the host at 10.0.2.2; Genymotion (10.0.3.2) and real
    // devices must pass API_BASE_URL.
    if (Platform.isAndroid) return 'http://10.0.2.2:$_devPort/api/v1';
    return 'http://localhost:$_devPort/api/v1';
  }

  /// Base URL for the password-reset web flow (routes/auth.php on the
  /// auth.{APP_DOMAIN} subdomain) — opened in an external browser, not called
  /// via the API client, since the backend only exposes it as a Blade form.
  static String get authBaseUrl {
    const fromEnv = String.fromEnvironment('AUTH_BASE_URL');
    if (fromEnv.isNotEmpty) {
      _requireHttpsOutsideDebug(fromEnv);
      return fromEnv;
    }
    // Dev fallback only: a non-debug build must be given an explicit https URL.
    _requireExplicitUrlOutsideDebug('AUTH_BASE_URL');
    return 'http://auth.localhost:$_devPort';
  }

  // Timeout configurations
  static const Duration connectTimeout = Duration(seconds: 30);
  static const Duration receiveTimeout = Duration(seconds: 30);
  static const Duration sendTimeout = Duration(seconds: 60);

  // Provider type names for display
  static const Map<String, String> providerTypeNames = {
    'doctor': 'Doctor',
    'nurse': 'Nurse',
    'pharmacist': 'Pharmacist',
    'lab_technician': 'Lab Technician',
    'radiologist': 'Radiologist',
    'therapist': 'Therapist',
    'other': 'Other Healthcare Professional',
  };

  // Organization type names for display
  static const Map<String, String> organizationTypeNames = {
    'hospital': 'Hospital',
    'clinic': 'Clinic',
    'pharmacy': 'Pharmacy',
    'laboratory': 'Laboratory',
    'diagnostic_center': 'Diagnostic Center',
    'other': 'Other',
  };

  static void printConfig() {
    debugPrint('App: $appName | API: $baseUrl');
  }
}
