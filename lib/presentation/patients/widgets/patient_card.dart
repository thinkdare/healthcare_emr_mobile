import 'package:flutter/material.dart';
import '../../../config/theme.dart';
import '../../../data/models/patient_models.dart';
import '../screens/patient_detail_screen.dart';

/// PatientCard
///
/// Used in both the patient list screen and the dashboard recent patients section.
/// Tapping navigates to the patient detail screen (Phase 2 stub, full in Phase 5).
class PatientCard extends StatelessWidget {
  final PatientModel patient;
  final VoidCallback? onTap;

  const PatientCard({
    super.key,
    required this.patient,
    this.onTap,
  });

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
                        if (patient.hasCriticalAllergies)
                          _AllergyBadge(),
                      ],
                    ),
                    const SizedBox(height: 4),

                    // Demographic line
                    Text(
                      _demographicLine,
                      style: TextStyle(
                          fontSize: 12, color: AppTheme.gray600),
                    ),

                    // Chronic conditions (first one only)
                    if (patient.chronicConditions.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        patient.chronicConditions.first,
                        style: TextStyle(
                          fontSize: 11,
                          color: AppTheme.secondaryColor,
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
              Icon(Icons.chevron_right,
                  color: AppTheme.gray600, size: 20),
            ],
          ),
        ),
      ),
    );
  }

  String get _demographicLine {
    final parts = <String>[
      patient.gender.capitalize(),
      patient.ageDisplay,
      if (patient.bloodType != null) patient.bloodType!,
    ];
    return parts.join(' · ');
  }

  void _onDefaultTap(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PatientDetailScreen(patient: patient),
      ),
    );
  }
}

// ── Avatar ────────────────────────────────────────────────────────────────────

class _PatientAvatar extends StatelessWidget {
  final PatientModel patient;
  const _PatientAvatar({required this.patient});

  Color get _avatarColor {
    if (patient.hasCriticalAllergies) {
      return AppTheme.errorColor.withValues(alpha: 0.15);
    }
    return patient.gender == 'female'
        ? AppTheme.secondaryColor.withValues(alpha: 0.15)
        : AppTheme.primaryColor.withValues(alpha: 0.15);
  }

  Color get _textColor {
    if (patient.hasCriticalAllergies) return AppTheme.errorColor;
    return patient.gender == 'female'
        ? AppTheme.secondaryColor
        : AppTheme.primaryColor;
  }

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: 24,
      backgroundColor: _avatarColor,
      child: Text(
        '${patient.firstName[0]}${patient.lastName[0]}',
        style: TextStyle(
          fontWeight: FontWeight.bold,
          color: _textColor,
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
          color: AppTheme.errorColor.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.warning, size: 10, color: AppTheme.errorColor),
            const SizedBox(width: 3),
            Text(
              'Allergy',
              style: TextStyle(
                fontSize: 10,
                color: AppTheme.errorColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  const _InfoRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 80,
          child: Text('$label:',
              style: TextStyle(
                  fontSize: 12,
                  color: AppTheme.gray600,
                  fontWeight: FontWeight.w500)),
        ),
        Expanded(
          child: Text(value,
              style: const TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w600)),
        ),
      ],
    );
  }
}

// ── Extension ─────────────────────────────────────────────────────────────────

extension StringCapitalize on String {
  String capitalize() =>
      isEmpty ? this : '${this[0].toUpperCase()}${substring(1)}';
}