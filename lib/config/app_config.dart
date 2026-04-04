import 'dart:io';

class AppConfig {
  static const String appName = 'Healthcare EMR System';
  static const String apiVersion = 'v1';

  // static const String _physicalDeviceBaseUrl = 'http://127.0.0.1:8000/api/v1';

  static String get baseUrl {
    if (Platform.isAndroid) {
      // return 'http://10.0.2.2:8000/api/v1';
      return 'http://10.0.3.2:8001/api/v1';
    } else if (Platform.isIOS) {
      return 'http://localhost:8001/api/v1';
    } else {
      return 'http://localhost:8001/api/v1';
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