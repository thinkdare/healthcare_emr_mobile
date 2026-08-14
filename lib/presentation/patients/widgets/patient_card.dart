import 'package:flutter/material.dart';
import '../../../data/models/patient_models.dart';
import '../screens/patient_detail_screen.dart';
import '../../../config/app_colors.dart';

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
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap ?? () => _onDefaultTap(context),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              // ── Avatar ────────────────────────────────────────────────────
              _PatientAvatar(patient: patient),
              const SizedBox(width: 14),

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
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 15,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (patient.hasCriticalAllergies) _AllergyBadge(),
                      ],
                    ),
                    const SizedBox(height: 4),

                    // MRN + demographic line
                    Text(
                      _demographicLine,
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.of(context).textSecondary,
                      ),
                    ),

                    // Chronic conditions (first one only)
                    if (patient.chronicConditions.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        patient.chronicConditions.first,
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.of(context).accent,
                          fontStyle: FontStyle.italic,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(width: 8),
              Icon(
                Icons.chevron_right,
                color: AppColors.of(context).textSecondary,
                size: 20,
              ),
            ],
          ),
        ),
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

  Color _avatarColor(BuildContext context) {
    if (patient.hasCriticalAllergies) {
      return AppColors.of(context).critical.withValues(alpha: 0.15);
    }
    return patient.gender == 'female'
        ? AppColors.of(context).accent.withValues(alpha: 0.15)
        : AppColors.of(context).accent.withValues(alpha: 0.15);
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

// ── Allergy badge ─────────────────────────────────────────────────────────────

class _AllergyBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Critical allergies',
      child: Container(
        margin: const EdgeInsets.only(left: 6),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: AppColors.of(context).critical.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.warning,
              size: 10,
              color: AppColors.of(context).critical,
            ),
            const SizedBox(width: 3),
            Text(
              'Allergy',
              style: TextStyle(
                fontSize: 10,
                color: AppColors.of(context).critical,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
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
