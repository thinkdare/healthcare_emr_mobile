import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/platform.dart';
import '../../../data/models/intra_grant_models.dart';
import '../../../data/providers/intra_transfer_provider.dart';

/// Incoming transfer request card shown in AccessGrantsScreen "Same Facility" tab.
/// Visually distinct from consultation cards — uses orange accent to signal
/// that acceptance permanently changes patient ownership.
class TransferRequestCard extends StatelessWidget {
  final IntraTransferModel transfer;

  const TransferRequestCard({super.key, required this.transfer});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.orange.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: transfer icon + patient name
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.swap_horiz, size: 18, color: Colors.orange.shade700),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        transfer.patientName ?? 'Patient',
                        style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      if (transfer.patientMrn != null)
                        Text('MRN: ${transfer.patientMrn}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant)),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text('Transfer Request',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: Colors.orange.shade800, fontWeight: FontWeight.w600)),
                ),
              ],
            ),

            if (transfer.handoverNotes != null && transfer.handoverNotes!.isNotEmpty) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(transfer.handoverNotes!,
                    style: theme.textTheme.bodySmall),
              ),
            ],

            const SizedBox(height: 12),

            // CTAs — confirmed update only
            Consumer<IntraTransferProvider>(
              builder: (context, provider, child) {
                final isActing = provider.isActing;

                return Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: isActing ? null : () => _decline(context),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: theme.colorScheme.error,
                          side: BorderSide(color: theme.colorScheme.error.withValues(alpha: 0.4)),
                        ),
                        child: const Text('Decline'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 2,
                      child: FilledButton(
                        onPressed: isActing ? null : () => _accept(context),
                        style: FilledButton.styleFrom(backgroundColor: Colors.orange.shade700),
                        child: isActing
                            ? const SizedBox(width: 16, height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Text('Accept Transfer'),
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _accept(BuildContext context) async {
    final provider = context.read<IntraTransferProvider>();
    final success  = await provider.accept(transfer.id);
    if (!context.mounted) return;
    if (!success) {
      showAdaptiveToast(context,
          provider.error ?? 'Failed to accept transfer.', type: ToastType.error);
    }
  }

  Future<void> _decline(BuildContext context) async {
    final provider = context.read<IntraTransferProvider>();
    final success  = await provider.decline(transfer.id);
    if (!context.mounted) return;
    if (!success) {
      showAdaptiveToast(context,
          provider.error ?? 'Failed to decline transfer.', type: ToastType.error);
    }
  }
}
