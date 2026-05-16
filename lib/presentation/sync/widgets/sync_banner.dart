// lib/presentation/sync/widgets/sync_banner.dart

import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/platform.dart';
import '../../../data/models/sync_models.dart';
import '../../../data/providers/sync_provider.dart';
import '../screens/sync_screen.dart';

/// Persistent banner between the nav bar and screen body.
/// Driven entirely by [SyncProvider]. Invisible when status is idle.
class SyncBanner extends StatefulWidget {
  const SyncBanner({super.key});

  @override
  State<SyncBanner> createState() => _SyncBannerState();
}

class _SyncBannerState extends State<SyncBanner> {
  bool _dismissed = false;
  Timer? _autoDismissTimer;

  @override
  void dispose() {
    _autoDismissTimer?.cancel();
    super.dispose();
  }

  void _scheduleAutoDismiss() {
    _autoDismissTimer?.cancel();
    _autoDismissTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) setState(() => _dismissed = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<SyncProvider>(
      builder: (context, sync, _) {
        if (sync.status != SyncStatus.synced && _dismissed) {
          _dismissed = false;
        }

        if (!_shouldShow(sync)) return const SizedBox.shrink();

        return _BannerTile(
          sync: sync,
          onDismiss: sync.status == SyncStatus.synced
              ? () => setState(() => _dismissed = true)
              : null,
          onSyncNow: _canSyncNow(sync) ? () => sync.sync() : null,
          onTap: sync.hasPendingConflicts
              ? () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const SyncScreen()),
                  )
              : null,
          scheduleAutoDismiss:
              sync.status == SyncStatus.synced ? _scheduleAutoDismiss : null,
        );
      },
    );
  }

  bool _shouldShow(SyncProvider sync) {
    if (sync.status == SyncStatus.idle) return false;
    if (sync.status == SyncStatus.synced && _dismissed) return false;
    return true;
  }

  bool _canSyncNow(SyncProvider sync) =>
      (sync.status == SyncStatus.idle || sync.status == SyncStatus.error) &&
      sync.isOnline;
}

class _BannerTile extends StatefulWidget {
  final SyncProvider sync;
  final VoidCallback? onDismiss;
  final VoidCallback? onSyncNow;
  final VoidCallback? onTap;
  final VoidCallback? scheduleAutoDismiss;

  const _BannerTile({
    required this.sync,
    this.onDismiss,
    this.onSyncNow,
    this.onTap,
    this.scheduleAutoDismiss,
  });

  @override
  State<_BannerTile> createState() => _BannerTileState();
}

class _BannerTileState extends State<_BannerTile> {
  @override
  void initState() {
    super.initState();
    widget.scheduleAutoDismiss?.call();
  }

  @override
  Widget build(BuildContext context) {
    final sync = widget.sync;
    final (bg, fg, icon, text) = _content(sync);

    return GestureDetector(
      onTap: widget.onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        width: double.infinity,
        color: bg,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            if (sync.status == SyncStatus.syncing)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: kIsIOS
                    ? CupertinoActivityIndicator(color: fg, radius: 8)
                    : SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: fg),
                      ),
              )
            else
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Icon(icon, size: 14, color: fg),
              ),
            Expanded(
              child: Text(text,
                  style: TextStyle(
                      color: fg, fontSize: 12, fontWeight: FontWeight.w500)),
            ),
            if (widget.onSyncNow != null) ...[
              const SizedBox(width: 8),
              GestureDetector(
                onTap: widget.onSyncNow,
                child: Text('Sync now',
                    style: TextStyle(
                        color: fg,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        decoration: TextDecoration.underline)),
              ),
            ],
            if (widget.onDismiss != null) ...[
              const SizedBox(width: 8),
              GestureDetector(
                onTap: widget.onDismiss,
                child: Icon(Icons.close, size: 14, color: fg),
              ),
            ],
          ],
        ),
      ),
    );
  }

  (Color, Color, IconData, String) _content(SyncProvider sync) {
    if (sync.hasPendingConflicts) {
      return (
        const Color(0xFFFFF3E0),
        const Color(0xFFE65100),
        Icons.warning_amber_rounded,
        '${sync.pendingConflicts} conflict${sync.pendingConflicts == 1 ? '' : 's'} need attention — Tap to review',
      );
    }
    return switch (sync.status) {
      SyncStatus.offline => (
          const Color(0xFFFFF8E1),
          const Color(0xFFF57F17),
          Icons.wifi_off,
          'No connection — changes saved locally',
        ),
      SyncStatus.syncing => (
          const Color(0xFFE3F2FD),
          const Color(0xFF1565C0),
          Icons.sync,
          sync.pendingLocalChanges > 0
              ? 'Syncing ${sync.pendingLocalChanges} change${sync.pendingLocalChanges == 1 ? '' : 's'}…'
              : 'Syncing…',
        ),
      SyncStatus.synced => (
          const Color(0xFFE8F5E9),
          const Color(0xFF2E7D32),
          Icons.check_circle_outline,
          'All changes synced',
        ),
      SyncStatus.error => (
          const Color(0xFFFFEBEE),
          const Color(0xFFC62828),
          Icons.error_outline,
          'Sync failed — tap "Sync now" to retry',
        ),
      SyncStatus.idle => (
          Colors.transparent,
          Colors.transparent,
          Icons.sync,
          '',
        ),
    };
  }
}
