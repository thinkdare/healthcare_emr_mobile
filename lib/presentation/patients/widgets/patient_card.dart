import 'package:flutter/material.dart';
import '../../../config/app_colors.dart';
import '../../../data/models/patient_models.dart';
import '../../shared/widgets/adaptive_badge.dart';
import '../../shared/widgets/adaptive_card.dart';
import '../../shared/widgets/adaptive_list_row.dart';
import '../screens/patient_detail_screen.dart';

/// PatientCard
///
/// Used in both the patient list screen and the dashboard recent patients section.
/// Tapping navigates to the patient detail screen (Phase 2 stub, full in Phase 5).
class PatientCard extends StatelessWidget {
  final PatientModel patient;
  final VoidCallback? onTap;

  const PatientCard({super.key, required this.patient, this.onTap});

  @override
  Widget build(BuildContext context) {
    final tokens = AppColors.of(context);
    return AdaptiveCard(
      onTap: onTap ?? () => _onDefaultTap(context),
      child: AdaptiveListRow(
        leading: _PatientAvatar(patient: patient),
        title: patient.fullName,
        subtitle: _demographicLine,
        trailing: patient.hasCriticalAllergies
            ? const AdaptiveBadge(label: 'Allergy', variant: BadgeVariant.critical)
            : Icon(Icons.chevron_right, color: tokens.textSecondary, size: 20),
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

  @override
  Widget build(BuildContext context) {
    final tokens = AppColors.of(context);
    final Color bg = patient.hasCriticalAllergies ? tokens.criticalTint : tokens.accentTint;
    final Color fg = patient.hasCriticalAllergies ? tokens.critical : tokens.accent;
    return CircleAvatar(
      radius: 24,
      backgroundColor: bg,
      child: Text(
        '${patient.firstName[0]}${patient.lastName[0]}',
        style: TextStyle(fontWeight: FontWeight.bold, color: fg, fontSize: 15),
      ),
    );
  }
}

// ── Extension ─────────────────────────────────────────────────────────────────

extension StringCapitalize on String {
  String capitalize() =>
      isEmpty ? this : '${this[0].toUpperCase()}${substring(1)}';
}
