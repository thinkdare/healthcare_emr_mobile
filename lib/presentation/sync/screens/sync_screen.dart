// lib/presentation/sync/screens/sync_screen.dart

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/platform.dart';
import '../../../data/models/sync_models.dart';
import '../../../data/providers/sync_provider.dart';
import '../widgets/conflict_card.dart';

class SyncScreen extends StatefulWidget {
  const SyncScreen({super.key});

  @override
  State<SyncScreen> createState() => _SyncScreenState();
}

class _SyncScreenState extends State<SyncScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<SyncProvider>().loadConflicts();
    });
  }

  @override
  Widget build(BuildContext context) {
    const title = 'Sync Status';
    return kIsIOS
        ? CupertinoPageScaffold(
            navigationBar:
                const CupertinoNavigationBar(middle: Text(title)),
            child: SafeArea(child: _Body()),
          )
        : Scaffold(
            appBar: AppBar(title: const Text(title)),
            body: _Body(),
          );
  }
}

class _Body extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Consumer<SyncProvider>(
      builder: (context, sync, _) => RefreshIndicator(
        onRefresh: () => sync.loadConflicts(),
        child: ListView(
          children: [
            _StatusCard(sync: sync),
            if (sync.conflicts.isEmpty)
              const _EmptyConflicts()
            else ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                child: Text(
                  '${sync.pendingConflicts} pending conflict${sync.pendingConflicts == 1 ? '' : 's'}',
                  style: const TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 13),
                ),
              ),
              ...sync.conflicts
                  .where((c) => c.isPending)
                  .map((c) => ConflictCard(
                        conflict: c,
                        onResolve: sync.resolveConflict,
                      )),
            ],
          ],
        ),
      ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  final SyncProvider sync;

  const _StatusCard({required this.sync});

  @override
  Widget build(BuildContext context) {
    final lastSynced = sync.lastSyncedAt;
    final lastSyncedText =
        lastSynced == null ? 'Never' : _relative(lastSynced);

    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.sync, size: 18),
                const SizedBox(width: 8),
                const Text('Sync Status',
                    style: TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 15)),
                const Spacer(),
                _StatusChip(status: sync.status),
              ],
            ),
            const SizedBox(height: 12),
            _InfoRow(label: 'Last synced', value: lastSyncedText),
            _InfoRow(
              label: 'Pending changes',
              value: sync.pendingLocalChanges > 0
                  ? '${sync.pendingLocalChanges} change${sync.pendingLocalChanges == 1 ? '' : 's'}'
                  : 'None',
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: sync.status == SyncStatus.syncing ||
                        sync.status == SyncStatus.offline
                    ? null
                    : () => sync.sync(),
                icon: const Icon(Icons.sync, size: 16),
                label: const Text('Sync Now'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _relative(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 60) return 'Just now';
    if (diff.inMinutes < 60) {
      return '${diff.inMinutes} minute${diff.inMinutes == 1 ? '' : 's'} ago';
    }
    if (diff.inHours < 24) {
      return '${diff.inHours} hour${diff.inHours == 1 ? '' : 's'} ago';
    }
    return '${diff.inDays} day${diff.inDays == 1 ? '' : 's'} ago';
  }
}

class _StatusChip extends StatelessWidget {
  final SyncStatus status;

  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    final (color, label) = switch (status) {
      SyncStatus.idle    => (Colors.grey, 'Idle'),
      SyncStatus.syncing => (Colors.blue, 'Syncing'),
      SyncStatus.synced  => (Colors.green, 'Synced'),
      SyncStatus.offline => (Colors.orange, 'Offline'),
      SyncStatus.error   => (Colors.red, 'Error'),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(label,
          style: TextStyle(
              fontSize: 11,
              color: color,
              fontWeight: FontWeight.w600)),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Text(label,
              style:
                  TextStyle(fontSize: 12, color: Colors.grey.shade600)),
          const Spacer(),
          Text(value,
              style: const TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}

class _EmptyConflicts extends StatelessWidget {
  const _EmptyConflicts();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Column(
        children: [
          Icon(Icons.check_circle_outline,
              size: 48, color: Colors.green.shade300),
          const SizedBox(height: 12),
          Text('No conflicts — all changes are in sync.',
              style: TextStyle(color: Colors.grey.shade600)),
        ],
      ),
    );
  }
}
