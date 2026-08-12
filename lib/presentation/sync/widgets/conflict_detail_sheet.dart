// lib/presentation/sync/widgets/conflict_detail_sheet.dart

import 'package:flutter/material.dart';
import '../../../core/sync/sync_diff_helper.dart';
import '../../../data/models/sync_models.dart';

class ConflictDetailSheet extends StatefulWidget {
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
  State<ConflictDetailSheet> createState() => _ConflictDetailSheetState();
}

class _ConflictDetailSheetState extends State<ConflictDetailSheet> {
  final _notesController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  String? _notesFieldName() => switch (widget.conflict.resourceType) {
        'appointments'  => 'notes',
        'lab_results'   => 'notes',
        'prescriptions' => 'special_instructions',
        _               => null,
      };

  Future<void> _submit(String strategy,
      {Map<String, dynamic>? mergedData}) async {
    setState(() => _isSubmitting = true);
    final ok = await widget.onResolve(
      widget.conflict.id,
      strategy,
      mergedData: mergedData,
      notes: _notesController.text.trim().isEmpty
          ? null
          : _notesController.text.trim(),
    );
    if (!mounted) return;
    setState(() => _isSubmitting = false);
    if (ok) {
      Navigator.of(context).pop();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to resolve. Please try again.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final conflict = widget.conflict;
    final diff = widget.diff;
    final notesField = _notesFieldName();

    Map<String, dynamic>? notesOnlyMerge;
    if (notesField != null &&
        conflict.clientData.containsKey(notesField) &&
        conflict.clientData[notesField] != null) {
      notesOnlyMerge = {
        ...conflict.serverData,
        notesField: conflict.clientData[notesField],
      };
    }

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 1.0,
      expand: false,
      builder: (context, scrollController) => Column(
        children: [
          Container(
            margin: const EdgeInsets.symmetric(vertical: 8),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text('Resolve Conflict',
                style: Theme.of(context).textTheme.titleMedium),
          ),
          const Divider(height: 1),
          Expanded(
            child: SingleChildScrollView(
              controller: scrollController,
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ...conflict.serverData.entries
                      .where((e) => !_isInternal(e.key))
                      .map((e) {
                    final clientVal = conflict.clientData[e.key];
                    final changed =
                        diff.changedByClient.contains(e.key);
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            width: 130,
                            child: Text(_label(e.key),
                                style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade600)),
                          ),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(e.value?.toString() ?? '—',
                                    style:
                                        const TextStyle(fontSize: 13)),
                                if (changed && clientVal != null) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                      'Your version: ${clientVal.toString()}',
                                      style: TextStyle(
                                          fontSize: 11,
                                          color: Colors.orange.shade700,
                                          fontStyle: FontStyle.italic)),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                  const SizedBox(height: 16),
                  const Text('Resolution notes (optional)',
                      style: TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  TextField(
                    controller: _notesController,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      hintText: 'Why did you choose this resolution?',
                      contentPadding: EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: EdgeInsets.fromLTRB(16, 12, 16,
                12 + MediaQuery.of(context).viewInsets.bottom),
            child: _isSubmitting
                ? const Center(child: CircularProgressIndicator())
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _ResolutionButton(
                        label: 'Keep mine',
                        subtitle:
                            'Apply your offline changes to the server',
                        color: Colors.green,
                        onTap: () => _submit('client_wins'),
                      ),
                      const SizedBox(height: 8),
                      _ResolutionButton(
                        label: 'Use server',
                        subtitle:
                            'Discard your changes, keep server version',
                        color: Colors.blue,
                        onTap: () => _submit('server_wins'),
                      ),
                      if (notesOnlyMerge != null) ...[
                        const SizedBox(height: 8),
                        _ResolutionButton(
                          label: 'Use server + keep my notes',
                          subtitle:
                              'Server data with your ${notesField!.replaceAll('_', ' ')} preserved',
                          color: Colors.purple,
                          onTap: () => _submit('merged',
                              mergedData: notesOnlyMerge),
                        ),
                      ],
                      const SizedBox(height: 8),
                      _ResolutionButton(
                        label: "I'll type it",
                        subtitle:
                            'Submit manual resolution with notes above',
                        color: Colors.grey,
                        onTap: () => _submit('manual'),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  bool _isInternal(String key) => const {
        'id', 'version', 'created_at', 'updated_at', 'deleted_at',
        'user_id', 'membership_id', 'last_modified_by',
      }.contains(key);

  String _label(String field) => field
      .replaceAll('_', ' ')
      .split(' ')
      .map((w) => w.isEmpty ? '' : w[0].toUpperCase() + w.substring(1))
      .join(' ');
}

class _ResolutionButton extends StatelessWidget {
  final String label;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _ResolutionButton({
    required this.label,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          border: Border.all(color: color.withValues(alpha: 0.4)),
          borderRadius: BorderRadius.circular(8),
          color: color.withValues(alpha: 0.06),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: color)),
            Text(subtitle,
                style: TextStyle(
                    fontSize: 11, color: Colors.grey.shade600)),
          ],
        ),
      ),
    );
  }
}
