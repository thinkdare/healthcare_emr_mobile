import 'package:flutter/foundation.dart';
import 'package:flutter_jailbreak_detection/flutter_jailbreak_detection.dart';

/// Checks once on startup whether the device is rooted (Android) or
/// jailbroken (iOS). Result is immutable for the lifetime of the app.
///
/// Never throws — a failed check is treated as uncompromised (fail open is
/// acceptable here because we want to avoid false-positive lock-outs for
/// clinical staff; the banner is a warning, not a hard block).
class RootDetectionProvider extends ChangeNotifier {
  bool _isCompromised = false;
  bool _checked = false;

  bool get isCompromised => _isCompromised;
  bool get checked => _checked;

  RootDetectionProvider() {
    _check();
  }

  Future<void> _check() async {
    if (kIsWeb || kDebugMode) {
      _checked = true;
      notifyListeners();
      return;
    }
    try {
      final jailbroken = await FlutterJailbreakDetection.jailbroken;
      final developerMode = await FlutterJailbreakDetection.developerMode;
      _isCompromised = jailbroken || developerMode;
    } catch (_) {
      _isCompromised = false;
    }
    _checked = true;
    notifyListeners();
  }
}
