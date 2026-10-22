import 'dart:convert';

import 'local_store.dart';

/// How long a device may keep working with no proof it is online and
/// authenticated (sync contract, section 7).
///
/// Past the ceiling, writes stop until the clinician signs in online or uses
/// break-glass. Break-glass is a logged continuation, not a hard stop: locking a
/// nurse out at hour 73 of an outage is a clinical-safety incident. Its reason is
/// attached to every reading written under it (it travels in the queued payload,
/// where the server keeps it for review).
class OfflineSessionPolicy {
  static const Duration defaultCeiling = Duration(hours: 72);
  static const Duration breakGlassWindow = Duration(hours: 8);

  final LocalStore store;
  final Duration ceiling;
  final DateTime Function() _now;

  OfflineSessionPolicy({required this.store, this.ceiling = defaultCeiling, DateTime Function()? clock})
      : _now = clock ?? DateTime.now;

  /// Call at login and whenever a sync round reaches the server.
  Future<void> markOnline() => store.setMeta('last_online_at', _now().toUtc().toIso8601String());

  Future<DateTime?> lastOnline() async {
    final raw = await store.getMeta('last_online_at');
    return raw == null ? null : DateTime.parse(raw);
  }

  /// Throws [CeilingReached] past the ceiling with no active break-glass;
  /// otherwise returns the active break-glass reason, or null for a normal write.
  Future<String?> checkWrite() async {
    final last = await lastOnline();
    if (last == null || _now().difference(last) <= ceiling) return null;

    final until = await store.getMeta('break_glass_until');
    if (until != null && DateTime.parse(until).isAfter(_now())) {
      return await store.getMeta('break_glass_reason');
    }

    throw CeilingReached(_now().difference(last));
  }

  /// Opens a time-limited break-glass window. A reason is required.
  Future<void> breakGlass(String reason) async {
    final trimmed = reason.trim();
    if (trimmed.isEmpty) throw ArgumentError('A break-glass reason is required.');
    // The server refuses a reason over 500 characters; catch it before it is queued.
    if (trimmed.runes.length > 500) throw ArgumentError('A break-glass reason can be at most 500 characters.');

    final now = _now().toUtc();
    await store.setMeta('break_glass_reason', trimmed);
    await store.setMeta('break_glass_until', now.add(breakGlassWindow).toIso8601String());

    final log = jsonDecode(await store.getMeta('break_glass_log') ?? '[]') as List;
    log.add({'at': now.toIso8601String(), 'reason': trimmed});
    await store.setMeta('break_glass_log', jsonEncode(log));
  }
}

class CeilingReached implements Exception {
  final Duration offlineFor;
  CeilingReached(this.offlineFor);

  @override
  String toString() =>
      'This device has been offline for ${offlineFor.inHours} hours. Sign in online, or continue with break-glass.';
}
