// Stub — full implementation in Task 8
import 'package:flutter/material.dart';
import '../../../core/sync/sync_diff_helper.dart';
import '../../../data/models/sync_models.dart';

class ConflictDetailSheet extends StatelessWidget {
  final SyncConflict conflict;
  final SyncDiff diff;
  final Future<bool> Function(String id, String strategy,
      {Map<String, dynamic>? mergedData, String? notes}) onResolve;

  const ConflictDetailSheet({
    super.key,
    required this.conflict,
    required this.diff,
    required this.onResolve,
  });

  @override
  Widget build(BuildContext context) =>
      const SizedBox(child: Center(child: CircularProgressIndicator()));
}
