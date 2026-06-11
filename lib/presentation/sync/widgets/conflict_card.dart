// lib/presentation/sync/widgets/conflict_card.dart

import 'package:flutter/material.dart';
import '../../../core/sync/sync_diff_helper.dart';
import '../../../data/models/sync_models.dart';
import 'conflict_detail_sheet.dart';

class ConflictCard extends StatelessWidget {
  final SyncConflict conflict;
  final Future<bool> Function(String id, String strategy,
      {Map<String, dynamic>? mergedData, String? notes}) onResolve;

  const ConflictCard({
    super.key,
    required this.conflict,
    required this.onResolve,
  });

  @override
  Widget build(BuildContext context) {
    final isDelete = conflict.isDeleteConflict;
    final diff = isDelete
        ? SyncDiffHelper.deleteConflictDiff(
            serverData: conflict.serverData,
            resourceType: conflict.resourceType,
          )
        : SyncDiffHelper.diff(
            clientData: conflict.clientData,
            serverData: conflict.serverData,
            resourceType: conflict.resourceType,
          );

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  isDelete ? Icons.delete_outline : _resourceIcon(conflict.resourceType),
                  size: 16,
                  color: isDelete ? Colors.red.shade700 : Colors.orange.shade700,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(_resourceTitle(conflict),
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 14)),
                ),
                if (isDelete)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Delete conflict',
                      style: TextStyle(fontSize: 10, color: Colors.red.shade700),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(diff.narrative,
                style: TextStyle(fontSize: 13, color: Colors.grey.shade700)),
            const SizedBox(height: 8),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text('Suggested: ${diff.suggestion}',
                  style: TextStyle(
                      fontSize: 11,
                      color: Colors.blue.shade800,
                      fontWeight: FontWeight.w500)),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _openDetailSheet(context, diff),
                    child: const Text('Review manually',
                        style: TextStyle(fontSize: 12)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _acceptSuggestion(context, diff),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue.shade700,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Accept',
                        style: TextStyle(fontSize: 12)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _acceptSuggestion(BuildContext context, SyncDiff diff) async {
    final ok = await onResolve(
      conflict.id,
      diff.strategy,
      mergedData: diff.mergedData,
    );
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content:
                Text('Failed to resolve conflict. Please try again.')),
      );
    }
  }

  Future<void> _openDetailSheet(BuildContext context, SyncDiff diff) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => ConflictDetailSheet(
        conflict: conflict,
        diff: diff,
        onResolve: onResolve,
      ),
    );
  }

  String _resourceTitle(SyncConflict c) {
    final type = c.resourceType
        .replaceAll('_', ' ')
        .split(' ')
        .map((w) => w.isEmpty ? '' : w[0].toUpperCase() + w.substring(1))
        .join(' ');
    final name = c.serverData['full_name'] as String? ??
        c.serverData['name'] as String? ??
        c.serverData['test_name'] as String? ??
        c.serverData['medication'] as String? ??
        c.serverData['appointment_type'] as String?;
    return name != null ? '$type — $name' : type;
  }

  IconData _resourceIcon(String resourceType) => switch (resourceType) {
        'patients'      => Icons.person,
        'prescriptions' => Icons.medication,
        'appointments'  => Icons.calendar_today,
        'lab_results'   => Icons.biotech,
        _               => Icons.description,
      };
}
