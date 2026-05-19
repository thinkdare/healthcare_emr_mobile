import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/platform.dart';
import '../../../data/providers/auth_provider.dart';
import '../../../data/providers/intra_transfer_provider.dart';
import '../../../data/repositories/facility_repository.dart';

/// Sheet for initiating a patient transfer.
/// Shown from PatientComplaintScreen when the doctor taps "Transfer".
class TransferRequestSheet extends StatefulWidget {
  final String patientId;
  final String? rosterEntryId;

  const TransferRequestSheet({
    super.key,
    required this.patientId,
    this.rosterEntryId,
  });

  @override
  State<TransferRequestSheet> createState() => _TransferRequestSheetState();
}

class _TransferRequestSheetState extends State<TransferRequestSheet> {
  final _notesCtrl = TextEditingController();

  List<Map<String, dynamic>> _colleagues = [];
  Map<String, dynamic>? _selectedColleague;
  bool _loadingColleagues = false;
  bool _saving = false;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _loadColleagues();
  }

  @override
  void dispose() {
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadColleagues() async {
    setState(() { _loadingColleagues = true; _loadError = null; });
    try {
      // Capture context-dependent values before the async gap
      final apiClient     = context.read<IntraTransferProvider>().repository.apiClient;
      final currentUserId = context.read<AuthProvider>().currentUserId;
      final repo  = FacilityRepository(apiClient: apiClient);
      final staff = await repo.listStaffAtCurrentTenant();

      // Exclude self — a doctor cannot transfer to themselves
      setState(() {
        _colleagues = staff
            .where((s) => s['user_id'] != currentUserId)
            .toList();
      });
    } catch (_) {
      setState(() => _loadError = 'Could not load colleagues. Try again.');
    } finally {
      setState(() => _loadingColleagues = false);
    }
  }

  Future<void> _submit() async {
    if (_selectedColleague == null) {
      showAdaptiveToast(context, 'Please select a colleague to transfer to.');
      return;
    }

    setState(() => _saving = true);

    final success = await context.read<IntraTransferProvider>().create(
      widget.patientId,
      {
        'to_provider_id':   _selectedColleague!['user_id'] as String,
        'to_membership_id': _selectedColleague!['membership_id'] as String,
        if (_notesCtrl.text.trim().isNotEmpty)
          'handover_notes': _notesCtrl.text.trim(),
        if (widget.rosterEntryId != null)
          'roster_entry_id': widget.rosterEntryId,
      },
    );

    if (!mounted) return;
    setState(() => _saving = false);

    if (success != null) {
      Navigator.of(context).pop(true);
    } else {
      showAdaptiveToast(
        context,
        context.read<IntraTransferProvider>().error ?? 'Failed to send transfer request.',
        type: ToastType.error,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.92,
      builder: (_, controller) => Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        ),
        child: Column(
          children: [
            // Drag handle
            Container(
              margin: const EdgeInsets.symmetric(vertical: 8),
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
              child: Row(
                children: [
                  const Icon(Icons.swap_horiz, size: 20),
                  const SizedBox(width: 8),
                  Text('Transfer Patient',
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.bold)),
                ],
              ),
            ),

            const Divider(height: 20),

            Expanded(
              child: ListView(
                controller: controller,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                children: [
                  // Colleague selection
                  Text('Transfer to', style: theme.textTheme.labelLarge),
                  const SizedBox(height: 8),

                  if (_loadingColleagues)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 24),
                        child: CircularProgressIndicator(),
                      ),
                    )
                  else if (_loadError != null)
                    _ErrorBanner(
                      message: _loadError!,
                      onRetry: _loadColleagues,
                    )
                  else if (_colleagues.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: Text(
                        'No other doctors are available at this facility.',
                        style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant),
                      ),
                    )
                  else
                    Container(
                      decoration: BoxDecoration(
                        border: Border.all(
                            color: theme.colorScheme.outline.withValues(alpha: 0.3)),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Column(
                        children: _colleagues.map((colleague) {
                          final isSelected =
                              _selectedColleague?['user_id'] == colleague['user_id'];
                          return InkWell(
                            onTap: () =>
                                setState(() => _selectedColleague = colleague),
                            borderRadius: BorderRadius.circular(10),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 12),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    radius: 18,
                                    backgroundColor: isSelected
                                        ? theme.colorScheme.primary.withValues(alpha: 0.15)
                                        : theme.colorScheme.surfaceContainerHighest,
                                    child: Text(
                                      (colleague['name'] as String)
                                          .split(' ')
                                          .map((w) => w.isNotEmpty ? w[0] : '')
                                          .take(2)
                                          .join(),
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: isSelected
                                            ? theme.colorScheme.primary
                                            : theme.colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          colleague['name'] as String,
                                          style: theme.textTheme.bodyMedium
                                              ?.copyWith(fontWeight: FontWeight.w600),
                                        ),
                                        if ((colleague['staff_type'] as String)
                                            .isNotEmpty)
                                          Text(
                                            (colleague['staff_type'] as String)
                                                .replaceAll('_', ' ')
                                                .toUpperCase(),
                                            style: theme.textTheme.labelSmall
                                                ?.copyWith(
                                                    color: theme.colorScheme
                                                        .onSurfaceVariant),
                                          ),
                                      ],
                                    ),
                                  ),
                                  if (isSelected)
                                    Icon(Icons.check_circle,
                                        color: theme.colorScheme.primary,
                                        size: 20),
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),

                  const SizedBox(height: 16),

                  // Handover notes
                  Text('Handover notes', style: theme.textTheme.labelLarge),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _notesCtrl,
                    maxLines: 4,
                    maxLength: 1000,
                    decoration: const InputDecoration(
                      hintText:
                          'e.g. Patient on IV fluids, awaiting CT results. Reassess in 30 min.',
                      border: OutlineInputBorder(),
                    ),
                  ),

                  const SizedBox(height: 24),
                ],
              ),
            ),

            Padding(
              padding: EdgeInsets.fromLTRB(
                  16, 8, 16, MediaQuery.of(context).viewInsets.bottom + 16),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed:
                          _saving ? null : () => Navigator.of(context).pop(false),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: FilledButton(
                      onPressed: _saving ? null : _submit,
                      child: _saving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white))
                          : const Text('Send Transfer Request'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorBanner({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline,
              size: 16,
              color: Theme.of(context).colorScheme.onErrorContainer),
          const SizedBox(width: 8),
          Expanded(
            child: Text(message,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onErrorContainer)),
          ),
          TextButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}
