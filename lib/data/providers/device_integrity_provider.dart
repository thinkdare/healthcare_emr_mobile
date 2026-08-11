import 'package:flutter/foundation.dart';
import 'package:safe_device/safe_device.dart';

/// Root/jailbreak detection — advisory only. This deliberately warns rather
/// than blocks: hard-blocking produces false-positive lockouts on
/// legitimately rooted MDM-managed hospital Android devices, which is
/// exactly the "clinician locked out during an outage" scenario the offline
/// sync work in this app exists to prevent. Detection failures (unsupported
/// platform, plugin exception) fail open — treated as "not compromised" —
/// for the same reason: a false positive here has a real cost (an
/// unnecessary warning shown to every user on that platform), while a false
/// negative just means this specific advisory signal is silent, which is
/// the same as not having it at all.
class DeviceIntegrityProvider extends ChangeNotifier {
  bool _isCompromised = false;
  bool _dismissed = false;
  bool _checked = false;

  bool get isCompromised => _isCompromised;
  bool get dismissed => _dismissed;
  bool get shouldWarn => _checked && _isCompromised && !_dismissed;

  Future<void> check() async {
    try {
      _isCompromised = await SafeDevice.isJailBroken;
    } catch (_) {
      _isCompromised = false;
    }
    _checked = true;
    notifyListeners();
  }

  void dismiss() {
    _dismissed = true;
    notifyListeners();
  }
}
