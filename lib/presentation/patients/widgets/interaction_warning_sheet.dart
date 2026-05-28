import 'package:flutter/material.dart';

import '../../../data/models/clinical_models.dart';

/// Shows drug interaction warnings and requires the doctor to explicitly
/// acknowledge them before a prescription can be saved.
///
/// Returns true  → doctor acknowledged, proceed with prescription.
/// Returns false → doctor cancelled, stay on form.
class InteractionWarningSheet extends StatelessWidget {
  final List<DrugInteraction> interactions;

  const InteractionWarningSheet({super.key, required this.interactions});

  static Future<bool> show(
    BuildContext context,
    List<DrugInteraction> interactions,
  ) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => InteractionWarningSheet(interactions: interactions),
    );
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final theme  = Theme.of(context);
    final count  = interactions.length;

    return DraggableScrollableSheet(
      initialChildSize: 0.65,
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
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
              child: Row(
                children: [
                  Icon(Icons.warning_amber_rounded,
                      color: theme.colorScheme.error, size: 28),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Drug Interaction Warning',
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          '$count interaction${count == 1 ? '' : 's'} detected with current medications',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const Divider(height: 24),

            // Interaction list
            Expanded(
              child: ListView.separated(
                controller: controller,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: interactions.length,
                separatorBuilder: (context, index) => const SizedBox(height: 8),
                itemBuilder: (_, i) => _InteractionCard(interaction: interactions[i]),
              ),
            ),

            // Action buttons
            Padding(
              padding: EdgeInsets.fromLTRB(
                  16, 12, 16, MediaQuery.of(context).viewInsets.bottom + 16),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: theme.colorScheme.error,
                      ),
                      onPressed: () => Navigator.of(context).pop(true),
                      child: const Text('I Acknowledge the Risk'),
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

class _InteractionCard extends StatelessWidget {
  final DrugInteraction interaction;

  const _InteractionCard({required this.interaction});

  @override
  Widget build(BuildContext context) {
    final theme  = Theme.of(context);
    final config = _severityConfig(interaction.severity, theme);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: config.background,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: config.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Severity badge + drug pair
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: config.badge,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  interaction.severity.toUpperCase(),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  interaction.drugs.join(' + '),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),

          if (interaction.description.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              interaction.description,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
              ),
            ),
          ],
        ],
      ),
    );
  }

  _SeverityConfig _severityConfig(String severity, ThemeData theme) {
    return switch (severity) {
      'high' => _SeverityConfig(
          background: Colors.red.shade50,
          border: Colors.red.shade200,
          badge: Colors.red.shade700,
        ),
      'moderate' => _SeverityConfig(
          background: Colors.amber.shade50,
          border: Colors.amber.shade300,
          badge: Colors.amber.shade800,
        ),
      _ => _SeverityConfig(
          background: Colors.yellow.shade50,
          border: Colors.yellow.shade400,
          badge: Colors.yellow.shade800,
        ),
    };
  }
}

class _SeverityConfig {
  final Color background;
  final Color border;
  final Color badge;

  const _SeverityConfig({
    required this.background,
    required this.border,
    required this.badge,
  });
}
