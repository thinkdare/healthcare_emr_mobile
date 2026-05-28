// lib/core/biometric/biometric_service.dart
//
// Wraps local_auth and the biometric-enabled preference.
// All callers go through this service — never import local_auth directly.

import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum BiometricAvailability {
  available,        // enrolled and ready
  notEnrolled,      // hardware present but no biometrics set up in device settings
  notSupported,     // device has no biometric hardware
  unavailable,      // platform error / permissions denied
}

class BiometricService {
  static const _prefKey = 'biometric_enabled';

  final LocalAuthentication _auth = LocalAuthentication();

  // ── Device capability ─────────────────────────────────────────────────────

  Future<BiometricAvailability> checkAvailability() async {
    try {
      final supported = await _auth.isDeviceSupported();
      if (!supported) return BiometricAvailability.notSupported;

      final canCheck = await _auth.canCheckBiometrics;
      if (!canCheck) return BiometricAvailability.notEnrolled;

      final biometrics = await _auth.getAvailableBiometrics();
      if (biometrics.isEmpty) return BiometricAvailability.notEnrolled;

      return BiometricAvailability.available;
    } on PlatformException {
      return BiometricAvailability.unavailable;
    }
  }

  /// Human-readable description of available biometric type for UI labels.
  Future<String> biometricLabel() async {
    try {
      final types = await _auth.getAvailableBiometrics();
      if (types.contains(BiometricType.face))        return 'Face ID';
      if (types.contains(BiometricType.fingerprint)) return 'Fingerprint';
      if (types.contains(BiometricType.iris))        return 'Iris';
      if (types.contains(BiometricType.strong))      return 'Biometrics';
      if (types.contains(BiometricType.weak))        return 'Biometrics';
    } on PlatformException {
      // ignore
    }
    return 'Biometrics';
  }

  // ── Preference ────────────────────────────────────────────────────────────

  Future<bool> isEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_prefKey) ?? false;
  }

  Future<void> setEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefKey, enabled);
  }

  // ── Authentication ────────────────────────────────────────────────────────

  /// Presents the native biometric / device-passcode prompt.
  /// Returns true on success, false if the user cancelled or failed.
  Future<bool> authenticate({String reason = 'Authenticate to access Voya'}) async {
    try {
      return await _auth.authenticate(
        localizedReason: reason,
        biometricOnly: false,             // allow device passcode as fallback
        sensitiveTransaction: true,
        persistAcrossBackgrounding: true, // keep dialog if app briefly backgrounds
      );
    } on PlatformException {
      return false;
    }
  }
}
