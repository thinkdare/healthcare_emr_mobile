import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:healthcare_emr_mobile/config/app_color_scope.dart';
import 'package:healthcare_emr_mobile/config/app_color_tokens.dart';
import 'package:healthcare_emr_mobile/data/models/patient_models.dart';
import 'package:healthcare_emr_mobile/presentation/patients/widgets/patient_card.dart';
import 'package:healthcare_emr_mobile/presentation/shared/widgets/adaptive_badge.dart';
import 'package:healthcare_emr_mobile/presentation/shared/widgets/adaptive_list_row.dart';

void main() {
  testWidgets('critical-allergy patient shows an AdaptiveBadge inside an AdaptiveListRow',
      (tester) async {
    // Note: hasCriticalAllergies is derived from the `allergies` list
    // (severity == life_threatening or severe) — there is no
    // has_critical_allergies field on PatientModel, so the fixture must
    // populate `allergies` rather than a boolean flag.
    const patient = PatientModel(
      id: '1',
      primaryProviderId: 'provider-1',
      firstName: 'James',
      lastName: 'Bello',
      gender: 'male',
      dateOfBirth: '1983-01-01',
      emergencyContactName: 'Jane Bello',
      emergencyContactPhone: '555-0100',
      allergies: [AllergyModel(name: 'Penicillin', severity: 'life_threatening')],
    );

    await tester.pumpWidget(MaterialApp(
      home: AppColorScope(
        tokens: AppColorTokens.light,
        child: Scaffold(body: PatientCard(patient: patient)),
      ),
    ));

    expect(find.byType(AdaptiveListRow), findsOneWidget);
    expect(find.byType(AdaptiveBadge), findsOneWidget);
    expect(find.text('James Bello'), findsOneWidget);
  });
}
