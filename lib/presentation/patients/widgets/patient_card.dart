import 'package:flutter/material.dart';
import '../../../config/theme.dart';
import '../../../data/models/patient_models.dart';

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
    // Full detail screen comes in Phase 5 (medical records).
    // For Phase 2 we show a quick bottom sheet with the basics.
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _PatientQuickView(patient: patient),
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

// ── Quick view bottom sheet ───────────────────────────────────────────────────

class _PatientQuickView extends StatelessWidget {
  final PatientModel patient;
  const _PatientQuickView({required this.patient});

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      expand: false,
      builder: (_, controller) => SingleChildScrollView(
        controller: controller,
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppTheme.gray600.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Name + badges
            Row(
              children: [
                _PatientAvatar(patient: patient),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(patient.fullName,
                          style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold)),
                      Text(
                        '${patient.gender.capitalize()} · ${patient.ageDisplay}',
                        style: TextStyle(
                            fontSize: 13, color: AppTheme.gray600),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Quick info
            _QuickInfoGrid(patient: patient),
            const SizedBox(height: 20),

            // Allergies
            if (patient.allergies.isNotEmpty) ...[
              _SectionHeader('Allergies'),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: patient.allergies
                    .map((a) => _AllergyChip(allergy: a))
                    .toList(),
              ),
              const SizedBox(height: 16),
            ],

            // Medications
            if (patient.currentMedications.isNotEmpty) ...[
              _SectionHeader('Current Medications'),
              const SizedBox(height: 8),
              ...patient.currentMedications.map(
                (m) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(children: [
                    Icon(Icons.medication,
                        size: 16, color: AppTheme.primaryColor),
                    const SizedBox(width: 8),
                    Expanded(
                        child: Text(m.displayDose,
                            style: const TextStyle(fontSize: 13))),
                  ]),
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Emergency contact
            _SectionHeader('Emergency Contact'),
            const SizedBox(height: 8),
            _InfoRow('Name', patient.emergencyContactName),
            const SizedBox(height: 4),
            _InfoRow('Phone', patient.emergencyContactPhone),

            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Close'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickInfoGrid extends StatelessWidget {
  final PatientModel patient;
  const _QuickInfoGrid({required this.patient});

  @override
  Widget build(BuildContext context) {
    final items = [
      ('DOB', patient.dateOfBirth),
      ('Blood Type', patient.bloodType ?? '—'),
      if (patient.phone != null) ('Phone', patient.phone!),
      if (patient.email != null) ('Email', patient.email!),
    ];

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 3.5,
      mainAxisSpacing: 4,
      crossAxisSpacing: 4,
      children: items
          .map((item) => _InfoRow(item.$1, item.$2))
          .toList(),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String text;
  const _SectionHeader(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(text,
        style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppTheme.gray600,
            letterSpacing: 0.5));
  }
}

class _AllergyChip extends StatelessWidget {
  final AllergyModel allergy;
  const _AllergyChip({required this.allergy});

  Color get _color {
    return switch (allergy.severity) {
      'life_threatening' => AppTheme.errorColor,
      'severe'           => AppTheme.errorColor,
      'moderate'         => AppTheme.warningColor,
      _                  => AppTheme.gray600,
    };
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: _color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _color.withValues(alpha: 0.4)),
      ),
      child: Text(
        '${allergy.name} (${allergy.severity.replaceAll('_', ' ')})',
        style: TextStyle(
            fontSize: 11, color: _color, fontWeight: FontWeight.w500),
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