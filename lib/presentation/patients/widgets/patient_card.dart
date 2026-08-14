import 'package:flutter/material.dart';
import '../../../data/models/patient_models.dart';
import '../screens/patient_detail_screen.dart';
import '../../../config/app_colors.dart';
import '../../../config/app_spacing.dart';
import '../../shared/widgets/adaptive_badge.dart';
import '../../shared/widgets/adaptive_card.dart';

/// PatientCard
///
/// Used in both the patient list screen and the dashboard recent patients section.
/// Tapping navigates to the patient detail screen (Phase 2 stub, full in Phase 5).
///
/// Note: this deliberately does not route through AdaptiveListRow — that
/// component's subtitle is a single string with a fixed style, and this row
/// needs two visually distinct subtitle lines (demographic meta text, plus
/// an accent-colored chronic-condition line), so the layout stays hand-rolled
/// inside an AdaptiveCard shell instead.
class PatientCard extends StatelessWidget {
  final PatientModel patient;
  final VoidCallback? onTap;

  const PatientCard({super.key, required this.patient, this.onTap});

  @override
  Widget build(BuildContext context) {
    final tokens = AppColors.of(context);
    return AdaptiveCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      onTap: onTap ?? () => _onDefaultTap(context),
      child: Row(
        children: [
          // ── Avatar ────────────────────────────────────────────────────
          _PatientAvatar(patient: patient),
          const SizedBox(width: AppSpacing.md),

          // ── Info ──────────────────────────────────────────────────────
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Name row
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        patient.fullName,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                          color: tokens.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (patient.hasCriticalAllergies) ...[
                      const SizedBox(width: AppSpacing.xs),
                      const Tooltip(
                        message: 'Critical allergies',
                        child: AdaptiveBadge(
                          label: 'Allergy',
                          variant: BadgeVariant.critical,
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: AppSpacing.xs),

                // MRN + demographic line
                Text(
                  _demographicLine,
                  style: TextStyle(fontSize: 12, color: tokens.textSecondary),
                ),

                // Chronic conditions (first one only)
                if (patient.chronicConditions.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    patient.chronicConditions.first,
                    style: TextStyle(
                      fontSize: 11,
                      color: tokens.accent,
                      fontStyle: FontStyle.italic,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(width: AppSpacing.sm),
          Icon(Icons.chevron_right, color: tokens.textSecondary, size: 20),
        ],
      ),
    );
  }

  String get _demographicLine {
    final parts = <String>[
      if (patient.mrn != null) patient.mrn!,
      patient.gender.capitalize(),
      patient.ageDisplay,
      if (patient.bloodType != null) patient.bloodType!,
    ];
    return parts.join(' · ');
  }

  void _onDefaultTap(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => PatientDetailScreen(patient: patient)),
    );
  }
}

// ── Avatar ────────────────────────────────────────────────────────────────────

class _PatientAvatar extends StatelessWidget {
  final PatientModel patient;
  const _PatientAvatar({required this.patient});

  // Gender doesn't currently vary the avatar tint (both branches resolve to
  // `accent`) — kept as a branch rather than collapsed so a future
  // gender-specific tint only requires filling in the other arm.
  Color _avatarColor(BuildContext context) {
    if (patient.hasCriticalAllergies) return AppColors.of(context).criticalTint;
    return patient.gender == 'female'
        ? AppColors.of(context).accentTint
        : AppColors.of(context).accentTint;
  }

  Color _textColor(BuildContext context) {
    if (patient.hasCriticalAllergies) return AppColors.of(context).critical;
    return patient.gender == 'female'
        ? AppColors.of(context).accent
        : AppColors.of(context).accent;
  }

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: 24,
      backgroundColor: _avatarColor(context),
      child: Text(
        '${patient.firstName[0]}${patient.lastName[0]}',
        style: TextStyle(
          fontWeight: FontWeight.bold,
          color: _textColor(context),
          fontSize: 15,
        ),
      ),
    );
  }
}

// ── Extension ─────────────────────────────────────────────────────────────────

extension StringCapitalize on String {
  String capitalize() =>
      isEmpty ? this : '${this[0].toUpperCase()}${substring(1)}';
}
