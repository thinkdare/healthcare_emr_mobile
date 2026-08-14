// test/patients/patient_detail_overview_order_test.dart
//
// Enforces the hard invariant from the design spec: when a patient has
// critical allergies, CriticalAlertCard must be the first card rendered
// in the Overview tab's scroll — not just present somewhere on screen.
// This survives future PRs that reorder sections or touch spacing, unlike
// a purely manual QA pass.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:healthcare_emr_mobile/config/app_color_scope.dart';
import 'package:healthcare_emr_mobile/config/app_color_tokens.dart';
import 'package:healthcare_emr_mobile/core/api/api_client.dart';
import 'package:healthcare_emr_mobile/core/database/local_database.dart';
import 'package:healthcare_emr_mobile/data/models/patient_models.dart';
import 'package:healthcare_emr_mobile/data/models/clinical_models.dart';
import 'package:healthcare_emr_mobile/data/models/clinical_record_models.dart';
import 'package:healthcare_emr_mobile/data/models/intra_grant_models.dart';
import 'package:healthcare_emr_mobile/data/providers/auth_provider.dart';
import 'package:healthcare_emr_mobile/data/providers/clinical_provider.dart';
import 'package:healthcare_emr_mobile/data/providers/intra_grant_provider.dart';
import 'package:healthcare_emr_mobile/data/repositories/auth_repository.dart';
import 'package:healthcare_emr_mobile/data/repositories/clinical_repository.dart';
import 'package:healthcare_emr_mobile/data/repositories/intra_grant_repository.dart';
import 'package:healthcare_emr_mobile/presentation/patients/screens/patient_detail_screen.dart';
import 'package:healthcare_emr_mobile/presentation/shared/widgets/adaptive_card.dart';
import 'package:healthcare_emr_mobile/presentation/shared/widgets/critical_alert_card.dart';

/// Returns empty lists for every clinical resource so ClinicalProvider.loadAll
/// resolves without error (no real network call) and the Overview tab renders
/// instead of the top-level _ErrorView.
class _TestClinicalRepository extends ClinicalRepository {
  _TestClinicalRepository({required super.apiClient, required super.db});

  @override
  Future<List<AppointmentModel>> getAppointments(
    String patientId, {
    String? status,
    int page = 1,
  }) async => [];

  @override
  Future<List<PrescriptionModel>> getPrescriptions(
    String patientId, {
    String? status,
    int page = 1,
  }) async => [];

  @override
  Future<List<LabResultModel>> getLabResults(
    String patientId, {
    String? status,
    int page = 1,
  }) async => [];

  @override
  Future<List<MedicalDocumentModel>> getDocuments(
    String patientId, {
    String? documentType,
    int page = 1,
  }) async => [];

  @override
  Future<List<VitalSignModel>> getVitalSigns(
    String patientId, {
    int page = 1,
  }) async => [];

  @override
  Future<List<DiagnosisModel>> getDiagnoses(
    String patientId, {
    String? status,
    int page = 1,
  }) async => [];

  @override
  Future<List<ProblemListModel>> getProblems(
    String patientId, {
    String? status,
    int page = 1,
  }) async => [];

  @override
  Future<List<ProcedureModel>> getProcedures(
    String patientId, {
    int page = 1,
  }) async => [];

  @override
  Future<List<ImmunizationModel>> getImmunizations(
    String patientId, {
    int page = 1,
  }) async => [];
}

/// Returns no clinical notes so the Notes tab (built eagerly by TabBarView
/// alongside Overview) doesn't touch the network or local sqlite cache.
class _TestIntraGrantRepository extends IntraGrantRepository {
  _TestIntraGrantRepository({required super.apiClient});

  @override
  Future<List<ClinicalNoteModel>> getPatientNotes(
    String patientId, {
    int page = 1,
  }) async => [];
}

/// Forces staffType to 'pharmacist' so the visible tab set is
/// [Overview, Prescriptions, Notes] — this keeps the widget tree under test
/// free of the Ward tab (which needs a WardWorkflowProvider) and the
/// Clinical Record tab, neither of which are relevant to this invariant.
class _FakeStaffAuthProvider extends AuthProvider {
  _FakeStaffAuthProvider({required super.repository, required super.localDatabase});

  @override
  String get staffType => 'pharmacist';
}

void main() {
  testWidgets('CriticalAlertCard is the first card in the Overview scroll',
      (tester) async {
    final patient = PatientModel.fromJson({
      'id': '1',
      'primary_provider_id': 'provider-1',
      'first_name': 'James',
      'last_name': 'Bello',
      'gender': 'male',
      'date_of_birth': '1983-01-01',
      'emergency_contact_name': 'Jane Bello',
      'emergency_contact_phone': '+234 800 1234567',
      'allergies': [
        {'name': 'Penicillin', 'severity': 'life_threatening'},
      ],
      'chronic_conditions': [],
    });

    final dummyApiClient = ApiClient();
    final authProvider = _FakeStaffAuthProvider(
      repository: AuthRepository(apiClient: dummyApiClient),
      localDatabase: LocalDatabase.instance,
    );
    final clinicalProvider = ClinicalProvider(
      repository: _TestClinicalRepository(
        apiClient: dummyApiClient,
        db: LocalDatabase.instance,
      ),
    );
    final intraGrantProvider = IntraGrantProvider(
      repository: _TestIntraGrantRepository(apiClient: dummyApiClient),
    );

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
          ChangeNotifierProvider<ClinicalProvider>.value(value: clinicalProvider),
          ChangeNotifierProvider<IntraGrantProvider>.value(value: intraGrantProvider),
        ],
        child: MaterialApp(
          home: AppColorScope(
            tokens: AppColorTokens.light,
            child: PatientDetailScreen(patient: patient),
          ),
        ),
      ),
    );

    // Pump to allow async initialization to complete.
    await tester.pumpAndSettle();

    // Target _OverviewTab's outer Column by its explicit key, not by type —
    // find.byType(Column).first would match whichever Column widget-tester
    // encounters first in the whole tree (AppBar, Scaffold, TabBarView,
    // AdaptiveCard/AdaptiveListRow internals, etc. all build their own
    // Columns), which can pass regardless of actual card order.
    final keyFinder = find.byKey(const Key('overview_tab_column'));
    expect(
      keyFinder,
      findsOneWidget,
      reason: 'Could not find Column with key overview_tab_column',
    );

    final column = tester.widget<Column>(keyFinder);
    final firstDataChild = column.children.firstWhere(
      (w) => w is CriticalAlertCard || w is AdaptiveCard,
    );
    expect(
      firstDataChild,
      isA<CriticalAlertCard>(),
      reason:
          'CriticalAlertCard must render before any other Overview card '
          'when the patient has critical allergies.',
    );
  });
}
