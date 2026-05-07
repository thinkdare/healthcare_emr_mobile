import 'dart:io';

class AppConfig {
  static const String appName = 'Healthcare EMR System';
  static const String apiVersion = 'v1';

  static String get baseUrl {
    if (Platform.isAndroid) {
      // 10.0.3.2 = host loopback on Genymotion; use 10.0.2.2 for standard AVD
      return 'http://10.0.3.2:8180/api/v1';
    } else if (Platform.isIOS) {
      return 'http://localhost:8180/api/v1';
    } else {
      return 'http://localhost:8180/api/v1';
    }
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
    print('App: $appName | API: $baseUrl');
  }
}