import 'dart:io';
import 'package:flutter/foundation.dart';

class AppConfig {
  static const String appName = 'Healthcare EMR System';
  static const String apiVersion = 'v1';

  static String get baseUrl {
    const fromEnv = String.fromEnvironment('API_BASE_URL');
    if (fromEnv.isNotEmpty) {
      assert(
        kDebugMode || fromEnv.startsWith('https://'),
        'Production build must use HTTPS. Got: $fromEnv',
      );
      return fromEnv;
    }
    // Dev fallback only — never present in a production build
    if (Platform.isAndroid) return 'http://10.0.3.2:8000/api/v1';
    return 'http://localhost:8000/api/v1';
  }

  /// Base URL for the password-reset web flow (routes/auth.php on the
  /// auth.{APP_DOMAIN} subdomain) — opened in an external browser, not called
  /// via the API client, since the backend only exposes it as a Blade form.
  static String get authBaseUrl {
    const fromEnv = String.fromEnvironment('AUTH_BASE_URL');
    if (fromEnv.isNotEmpty) {
      assert(
        kDebugMode || fromEnv.startsWith('https://'),
        'Production build must use HTTPS. Got: $fromEnv',
      );
      return fromEnv;
    }
    // Dev fallback only — never present in a production build.
    return 'http://auth.localhost:8000';
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