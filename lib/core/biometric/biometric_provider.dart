// lib/core/biometric/biometric_provider.dart
//
// Holds the app-lock state. Shells watch this and overlay BiometricLockScreen
// when isLocked is true. Main.dart drives lock/unlock via the lifecycle listener.

import 'package:flutter/foundation.dart';
import 'biometric_service.dart';

class BiometricProvider extends ChangeNotifier {
  final BiometricService service;

  BiometricProvider({required this.service});

  bool _isLocked = false;
  DateTime? _backgroundedAt;

  bool get isLocked => _isLocked;

  static const _lockThreshold = Duration(minutes: 5);

  // Called when the app goes to background (onInactive / onHide).
  void recordBackground() {
    _backgroundedAt = DateTime.now();
  }

  // Called on cold start (token already exists → authenticated).
  // Locks if biometric is enabled.
  Future<void> lockIfEnabled() async {
    if (await service.isEnabled()) {
      _isLocked = true;
      notifyListeners();
    }
  }

  // Called on resume. Locks if biometric is enabled and threshold exceeded.
  Future<void> checkResumeLock() async {
    if (!await service.isEnabled()) return;

    final bg = _backgroundedAt;
    if (bg == null) return; // first launch — handled by lockIfEnabled()

    if (DateTime.now().difference(bg) >= _lockThreshold) {
      _isLocked = true;
      notifyListeners();
    }
    _backgroundedAt = null;
  }

  // Called by BiometricLockScreen after successful authentication.
  void unlock() {
    _isLocked = false;
    notifyListeners();
  }
}
