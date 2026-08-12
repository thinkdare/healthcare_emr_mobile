import 'package:flutter/material.dart';
import '../../../config/app_colors.dart';
import '../../../config/app_spacing.dart';

/// High-contrast, safety-first card for life-threatening patient
/// information (e.g. critical allergies). Any screen surfacing this kind
/// of data MUST use this component and MUST render it before any other
/// content in the same scroll — see Task 27 (_OverviewTab) and the
/// dedicated ordering test in test/patients/patient_detail_overview_test.dart.
class CriticalAlertCard extends StatelessWidget {
  final String title;
  final List<String> items;

  const CriticalAlertCard({
    super.key,
    required this.title,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = AppColors.of(context);
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: tokens.criticalTint,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: tokens.criticalBorder, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.warning_rounded, size: 18, color: tokens.critical),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  title,
                  overflow: TextOverflow.ellipsis,
                  maxLines: 2,
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                    letterSpacing: 0.02,
                    color: tokens.critical,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: items
                .map((item) => Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.sm, vertical: 4),
                      decoration: BoxDecoration(
                        color: tokens.surface,
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                        border: Border.all(color: tokens.criticalBorder),
                      ),
                      child: Text(
                        item,
                        style: TextStyle(fontSize: 12, color: tokens.critical),
                      ),
                    ))
                .toList(),
          ),
        ],
      ),
    );
  }
}
