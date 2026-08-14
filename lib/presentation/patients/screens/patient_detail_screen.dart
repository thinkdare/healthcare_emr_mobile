import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/platform.dart';
import '../../../data/models/patient_models.dart';
import '../../../data/models/clinical_models.dart';
import '../../../data/providers/auth_provider.dart';
import '../../../data/providers/clinical_provider.dart';
import '../../../data/providers/patient_provider.dart';
import '../../../data/models/intra_grant_models.dart';
import '../../../data/providers/intra_grant_provider.dart';
import '../../../data/providers/referral_provider.dart';
import '../../../data/models/ward_models.dart';
import '../../../data/providers/ward_workflow_provider.dart';
import '../../../data/providers/patient_message_provider.dart';
import '../../../data/providers/patient_consent_provider.dart';
import '../../referrals/widgets/create_referral_sheet.dart';
import '../widgets/ward_request_sheets.dart';
import 'patient_messages_screen.dart';
import 'patient_consent_screen.dart';
import '../widgets/clinical_forms.dart';
import '../widgets/clinical_record_tab.dart';
import '../widgets/clinical_record_forms.dart';
import 'patient_form_screen.dart';
import '../../../config/app_colors.dart';
import '../../../config/app_spacing.dart';
import '../../shared/widgets/adaptive_card.dart';
import '../../shared/widgets/adaptive_badge.dart';
import '../../shared/widgets/adaptive_list_row.dart';
import '../../shared/widgets/critical_alert_card.dart';

class PatientDetailScreen extends StatefulWidget {
  final PatientModel patient;

  const PatientDetailScreen({super.key, required this.patient});

  @override
  State<PatientDetailScreen> createState() => _PatientDetailScreenState();
}

// Tabs available to each staff type (by index into _allTabs).
// 0=Overview 1=Appointments 2=Prescriptions 3=Lab Results 4=Documents 5=Clinical Record 6=Notes 7=Ward
const _nurseTabIndices = [0, 1, 5, 6, 7];
const _pharmacistTabIndices = [0, 2, 6];
const _labTechTabIndices = [0, 3, 6];
const _doctorTabIndices = [0, 1, 2, 3, 4, 5, 6, 7];

List<int> _tabIndicesFor(String staffType) => switch (staffType) {
  'nurse' => _nurseTabIndices,
  'pharmacist' => _pharmacistTabIndices,
  'lab_technician' || 'lab_tech' => _labTechTabIndices,
  _ => _doctorTabIndices, // doctor, admin, other
};

class _PatientDetailScreenState extends State<PatientDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;
  late PatientModel _patient;
  int _currentTab = 0;
  int _iosSegment = 0;
  late List<int> _visibleIndices;

  @override
  void initState() {
    super.initState();
    _patient = widget.patient;
    final staffType = context.read<AuthProvider>().staffType;
    _visibleIndices = _tabIndicesFor(staffType);
    _tabs = TabController(length: _visibleIndices.length, vsync: this);
    _tabs.addListener(() {
      if (!_tabs.indexIsChanging) {
        setState(() => _currentTab = _visibleIndices[_tabs.index]);
      }
    });
    _currentTab = _visibleIndices.first;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ClinicalProvider>().loadAll(_patient.id);
      if (_visibleIndices.contains(7)) {
        context.read<WardWorkflowProvider>().loadAll(_patient.id);
      }
    });
  }

  Future<void> _openClinicalForm() async {
    final auth = context.read<AuthProvider>();
    Widget? form;
    final tabIndex = kIsIOS ? _visibleIndices[_iosSegment] : _currentTab;

    switch (tabIndex) {
      case 1: // Appointments
        form = const AppointmentForm();
        break;
      case 2: // Prescriptions
        if (auth.staffType == 'pharmacist') {
          // Pharmacists use the fill dialog on individual cards, not the FAB.
          showAdaptiveToast(
            context,
            'Tap the Fill button on a prescription to dispense it',
          );
          return;
        }
        if (!auth.canPrescribe) {
          showAdaptiveToast(context, 'You do not have prescribing privileges');
          return;
        }
        form = const PrescriptionForm();
        break;
      case 3: // Lab Results
        if (auth.staffType == 'lab_technician' ||
            auth.staffType == 'lab_tech') {
          showAdaptiveToast(
            context,
            'Tap the Record button on a lab order to enter results',
          );
          return;
        }
        if (!auth.canOrderLabs) {
          showAdaptiveToast(context, 'You do not have lab ordering privileges');
          return;
        }
        form = const LabOrderForm();
        break;
      case 4: // Documents
        form = const DocumentUploadForm();
        break;
      case 5: // Clinical Record — picker selects which resource to add
        await _showClinicalRecordFormPicker();
        return;
      default:
        return;
    }

    if (!mounted) return;
    final created = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => form!,
    );

    if (created == true && mounted) {
      final clinical = context.read<ClinicalProvider>();
      switch (tabIndex) {
        case 1:
          clinical.loadAppointments();
          break;
        case 2:
          clinical.loadPrescriptions();
          break;
        case 3:
          clinical.loadLabResults();
          break;
        case 4:
          clinical.loadDocuments();
          break;
      }
    }
  }

  Future<void> _showClinicalRecordFormPicker() async {
    Type? formType;

    if (kIsIOS) {
      await showCupertinoModalPopup<void>(
        context: context,
        builder: (ctx) => CupertinoActionSheet(
          title: const Text('Add Clinical Record'),
          actions: [
            CupertinoActionSheetAction(
              onPressed: () {
                formType = VitalSignForm;
                Navigator.of(ctx).pop();
              },
              child: const Text('Vital Signs'),
            ),
            CupertinoActionSheetAction(
              onPressed: () {
                formType = DiagnosisForm;
                Navigator.of(ctx).pop();
              },
              child: const Text('Diagnosis'),
            ),
            CupertinoActionSheetAction(
              onPressed: () {
                formType = ProblemForm;
                Navigator.of(ctx).pop();
              },
              child: const Text('Problem'),
            ),
            CupertinoActionSheetAction(
              onPressed: () {
                formType = ProcedureForm;
                Navigator.of(ctx).pop();
              },
              child: const Text('Procedure'),
            ),
            CupertinoActionSheetAction(
              onPressed: () {
                formType = ImmunizationForm;
                Navigator.of(ctx).pop();
              },
              child: const Text('Immunization'),
            ),
          ],
          cancelButton: CupertinoActionSheetAction(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
        ),
      );
    } else {
      formType = await showModalBottomSheet<Type>(
        context: context,
        builder: (ctx) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.monitor_heart),
                title: const Text('Vital Signs'),
                onTap: () => Navigator.pop(ctx, VitalSignForm),
              ),
              ListTile(
                leading: const Icon(Icons.medical_information),
                title: const Text('Diagnosis'),
                onTap: () => Navigator.pop(ctx, DiagnosisForm),
              ),
              ListTile(
                leading: const Icon(Icons.list_alt),
                title: const Text('Problem'),
                onTap: () => Navigator.pop(ctx, ProblemForm),
              ),
              ListTile(
                leading: const Icon(Icons.local_hospital),
                title: const Text('Procedure'),
                onTap: () => Navigator.pop(ctx, ProcedureForm),
              ),
              ListTile(
                leading: const Icon(Icons.vaccines),
                title: const Text('Immunization'),
                onTap: () => Navigator.pop(ctx, ImmunizationForm),
              ),
            ],
          ),
        ),
      );
    }

    if (formType == null || !mounted) return;

    final Widget form = switch (formType) {
      _ when formType == DiagnosisForm => const DiagnosisForm(),
      _ when formType == ProblemForm => const ProblemForm(),
      _ when formType == ProcedureForm => const ProcedureForm(),
      _ when formType == ImmunizationForm => const ImmunizationForm(),
      _ => const VitalSignForm(),
    };

    final created = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => form,
    );

    if (created == true && mounted) {
      context.read<ClinicalProvider>().loadAll(_patient.id);
    }
  }

  Future<void> _openEdit() async {
    final updated = await Navigator.of(context).push<PatientModel>(
      kIsIOS
          ? CupertinoPageRoute(
              builder: (_) => PatientFormScreen(patient: _patient),
            )
          : MaterialPageRoute(
              builder: (_) => PatientFormScreen(patient: _patient),
            ),
    );
    if (updated != null && mounted) {
      setState(() => _patient = updated);
      // Keep PatientProvider list in sync
      context.read<PatientProvider>().setSelectedPatient(updated);
    }
  }

  Future<void> _openReferralSheet() async {
    if (_patient.globalPatientId == null) {
      showAdaptiveToast(context, 'Patient global ID not available');
      return;
    }
    await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => CreateReferralSheet(patient: _patient),
    );
    if (mounted) {
      final tenantId = context.read<AuthProvider>().activeTenantId ?? '';
      context.read<ReferralProvider>().loadReferrals(currentTenantId: tenantId);
    }
  }

  Future<void> _activateRecord() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Activate Patient Record'),
        content: const Text(
          'Records department staff only. This opens a time-limited window '
          'for clinical write access to this patient.',
        ),
        actions: [
          AdaptiveTextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          AdaptiveFilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Activate'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final ok = await context.read<PatientProvider>().activatePatient(
      _patient.id,
    );
    if (!mounted) return;
    showAdaptiveToast(
      context,
      ok
          ? 'Patient record activated'
          : context.read<PatientProvider>().error ??
                'Failed to activate record',
      type: ok ? ToastType.success : ToastType.error,
    );
  }

  Future<void> _showAuditLog() async {
    final logs = await context.read<PatientProvider>().getAuditLog(_patient.id);
    if (!mounted) return;
    if (logs == null) {
      showAdaptiveToast(
        context,
        context.read<PatientProvider>().error ?? 'Failed to load audit log',
        type: ToastType.error,
      );
      return;
    }
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _PatientAuditLogSheet(logs: logs),
    );
  }

  Future<void> _showMoreActions(bool canViewAuditLog) async {
    String? choice;
    await showCupertinoModalPopup<void>(
      context: context,
      builder: (_) => CupertinoActionSheet(
        actions: [
          CupertinoActionSheetAction(
            onPressed: () {
              choice = 'activate';
              Navigator.of(context).pop();
            },
            child: const Text('Activate Record'),
          ),
          if (canViewAuditLog)
            CupertinoActionSheetAction(
              onPressed: () {
                choice = 'audit_log';
                Navigator.of(context).pop();
              },
              child: const Text('View Audit Log'),
            ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
      ),
    );
    if (choice == 'activate') _activateRecord();
    if (choice == 'audit_log') _showAuditLog();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = _patient;
    final auth = context.read<AuthProvider>();
    final canEdit =
        auth.staffType == 'doctor' ||
        auth.staffType == 'admin' ||
        auth.staffType == 'nurse';
    final isSuperAdmin = auth.currentUser?.isSuperAdmin ?? false;
    final canViewAuditLog =
        isSuperAdmin || auth.currentUserId == p.primaryProviderId;

    if (kIsIOS) {
      final iosTabIndex = _visibleIndices[_iosSegment];
      final showAdd = iosTabIndex >= 1;
      return CupertinoPageScaffold(
        navigationBar: CupertinoNavigationBar(
          middle: Text(p.fullName),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (showAdd)
                CupertinoButton(
                  padding: EdgeInsets.zero,
                  onPressed: _openClinicalForm,
                  child: const Icon(CupertinoIcons.add),
                ),
              if (auth.isStaff)
                CupertinoButton(
                  padding: EdgeInsets.zero,
                  onPressed: _openReferralSheet,
                  child: const Icon(
                    CupertinoIcons.arrow_right_arrow_left_circle,
                  ),
                ),
              if (canEdit)
                CupertinoButton(
                  padding: EdgeInsets.zero,
                  onPressed: _openEdit,
                  child: const Icon(CupertinoIcons.pencil),
                ),
              CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: () => context.read<ClinicalProvider>().loadAll(p.id),
                child: const Icon(CupertinoIcons.refresh),
              ),
              CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: () => _showMoreActions(canViewAuditLog),
                child: const Icon(CupertinoIcons.ellipsis_circle),
              ),
            ],
          ),
        ),
        child: SafeArea(
          child: Consumer<ClinicalProvider>(
            builder: (context, clinical, _) {
              if (clinical.isLoading) {
                return const Center(child: CupertinoActivityIndicator());
              }
              if (clinical.error != null) {
                return _ErrorView(
                  message: clinical.error!,
                  onRetry: () => clinical.loadAll(p.id),
                );
              }
              final allTabViews = [
                _OverviewTab(patient: _patient),
                _AppointmentsTab(patientId: _patient.id),
                _PrescriptionsTab(patientId: _patient.id),
                _LabResultsTab(patientId: _patient.id),
                _DocumentsTab(patientId: _patient.id),
                const ClinicalRecordTab(),
                _NotesTab(patient: _patient),
                _WardTab(patientId: _patient.id),
              ];
              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    child: CupertinoSlidingSegmentedControl<int>(
                      groupValue: _iosSegment,
                      onValueChanged: (v) =>
                          setState(() => _iosSegment = v ?? 0),
                      children: {
                        for (int i = 0; i < _visibleIndices.length; i++)
                          i: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: Text(
                              const [
                                'Overview',
                                'Appts',
                                'Rx',
                                'Labs',
                                'Docs',
                                'Clinical',
                                'Notes',
                                'Ward',
                              ][_visibleIndices[i]],
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                      },
                    ),
                  ),
                  Expanded(
                    child: IndexedStack(
                      index: _iosSegment,
                      children: [
                        for (final i in _visibleIndices) allTabViews[i],
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      );
    }

    // Android path
    return Scaffold(
      floatingActionButton: _currentTab >= 1 && _currentTab <= 4
          ? FloatingActionButton(
              onPressed: _openClinicalForm,
              tooltip: switch (_currentTab) {
                1 => 'Book Appointment',
                2 =>
                  auth.staffType == 'pharmacist'
                      ? 'Fill Prescription'
                      : 'New Prescription',
                3 =>
                  auth.staffType == 'lab_technician' ||
                          auth.staffType == 'lab_tech'
                      ? 'Record Results'
                      : 'Order Lab Test',
                4 => 'Upload Document',
                _ => 'Add',
              },
              child: Icon(_currentTab == 4 ? Icons.upload_file : Icons.add),
            )
          : null,
      appBar: AppBar(
        title: Text(p.fullName),
        actions: [
          if (auth.isStaff)
            IconButton(
              icon: const Icon(Icons.send_outlined),
              tooltip: 'Refer patient',
              onPressed: _openReferralSheet,
            ),
          if (canEdit)
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              tooltip: 'Edit patient',
              onPressed: _openEdit,
            ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: () => context.read<ClinicalProvider>().loadAll(p.id),
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'activate') _activateRecord();
              if (value == 'audit_log') _showAuditLog();
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'activate',
                child: Row(
                  children: [
                    Icon(Icons.lock_open_outlined, size: 20),
                    SizedBox(width: 8),
                    Text('Activate Record'),
                  ],
                ),
              ),
              if (canViewAuditLog)
                const PopupMenuItem(
                  value: 'audit_log',
                  child: Row(
                    children: [
                      Icon(Icons.history, size: 20),
                      SizedBox(width: 8),
                      Text('View Audit Log'),
                    ],
                  ),
                ),
            ],
          ),
        ],
        bottom: TabBar(
          controller: _tabs,
          isScrollable: true,
          tabs: [
            for (final i in _visibleIndices)
              Tab(
                text: const [
                  'Overview',
                  'Appointments',
                  'Prescriptions',
                  'Lab Results',
                  'Documents',
                  'Clinical Record',
                  'Notes',
                  'Ward',
                ][i],
              ),
          ],
        ),
      ),
      body: Consumer<ClinicalProvider>(
        builder: (context, clinical, _) {
          if (clinical.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (clinical.error != null) {
            return _ErrorView(
              message: clinical.error!,
              onRetry: () => clinical.loadAll(p.id),
            );
          }
          final allTabViews = [
            _OverviewTab(patient: _patient),
            _AppointmentsTab(patientId: _patient.id),
            _PrescriptionsTab(patientId: _patient.id),
            _LabResultsTab(patientId: _patient.id),
            _DocumentsTab(patientId: _patient.id),
            const ClinicalRecordTab(),
            _NotesTab(patient: _patient),
            _WardTab(patientId: _patient.id),
          ];
          return TabBarView(
            controller: _tabs,
            children: [for (final i in _visibleIndices) allTabViews[i]],
          );
        },
      ),
    );
  }
}

// ── Patient Audit Log ─────────────────────────────────────────────────────────

class _PatientAuditLogSheet extends StatelessWidget {
  final List<Map<String, dynamic>> logs;
  const _PatientAuditLogSheet({required this.logs});

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        final tokens = AppColors.of(context);
        return Column(
          children: [
            const SizedBox(height: AppSpacing.md),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: tokens.textSecondary.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Text(
                'Audit Log',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: tokens.textPrimary,
                ),
              ),
            ),
            Expanded(
              child: logs.isEmpty
                  ? Center(
                      child: Text(
                        'No audit entries',
                        style: TextStyle(color: tokens.textSecondary),
                      ),
                    )
                  : ListView.separated(
                      controller: scrollController,
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.lg,
                      ),
                      itemCount: logs.length,
                      separatorBuilder: (_, _) =>
                          Divider(height: 1, color: tokens.surfaceBorder),
                      itemBuilder: (context, i) {
                        final log = logs[i];
                        return AdaptiveListRow(
                          leading: Icon(
                            log['was_emergency'] == true
                                ? Icons.warning_amber
                                : Icons.fingerprint,
                            color: log['was_emergency'] == true
                                ? tokens.critical
                                : tokens.textSecondary,
                            size: 20,
                          ),
                          title:
                              '${log['action'] ?? ''} · ${log['resource_type'] ?? ''}',
                          subtitle:
                              '${log['access_authority'] ?? ''} · ${log['accessed_at'] ?? ''}'
                              '${log['was_offline'] == true ? ' · offline' : ''}',
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }
}

// ── Overview Tab ─────────────────────────────────────────────────────────────

class _OverviewTab extends StatelessWidget {
  final PatientModel patient;
  const _OverviewTab({required this.patient});

  @override
  Widget build(BuildContext context) {
    final p = patient;
    final tokens = AppColors.of(context);
    return SingleChildScrollView(
      // Horizontal inset comes from AdaptiveCard/CriticalAlertCard's own
      // 16px margin; the _SectionHeader siblings below carry a matching
      // Padding(horizontal: 16) so headers and cards stay flush.
      padding: const EdgeInsets.fromLTRB(0, AppSpacing.lg, 0, AppSpacing.xl),
      child: Column(
        // Keyed so the safety-invariant test can target this exact Column
        // deterministically — do not remove this key, and do not rely on
        // find.byType(Column).first in any test, since AdaptiveCard/
        // AdaptiveListRow and ancestor widgets (AppBar, Scaffold,
        // TabBarView) also build Columns.
        key: const Key('overview_tab_column'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Critical allergies — MUST stay first. See CriticalAlertCard's
          // doc comment and test/patients/patient_detail_overview_order_test.dart.
          if (p.hasCriticalAllergies)
            CriticalAlertCard(
              title: 'CRITICAL ALLERGY',
              items: p.allergies
                  .where((a) => a.isLifeThreatening || a.isSevere)
                  .map((a) => '${a.name} — ${a.severity.replaceAll('_', ' ')}')
                  .toList(),
            ),

          // Patient summary card
          AdaptiveCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 32,
                      backgroundColor: tokens.accentTint,
                      child: Text(
                        p.firstName[0] + p.lastName[0],
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: tokens.accent,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.lg),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            p.fullName,
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: tokens.textPrimary,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          Text(
                            '${p.ageDisplay} · ${p.gender} · ${p.bloodType ?? 'Blood type unknown'}',
                            style: TextStyle(
                              color: tokens.textSecondary,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                Divider(height: AppSpacing.xl, color: tokens.surfaceBorder),
                if (p.mrn != null) _InfoRow('MRN', p.mrn!),
                _InfoRow('Date of Birth', p.dateOfBirth),
                if (p.phone != null) _InfoRow('Phone', p.phone!),
                if (p.email != null) _InfoRow('Email', p.email!),
                if (p.address != null) _InfoRow('Address', p.address!),
                const SizedBox(height: AppSpacing.sm),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.message_outlined, size: 18),
                        label: const Text('Messages'),
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => ChangeNotifierProvider.value(
                              value: context.read<PatientMessageProvider>(),
                              child: PatientMessagesScreen(
                                patientId: p.id,
                                patientName: p.fullName,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(
                          Icons.privacy_tip_outlined,
                          size: 18,
                        ),
                        label: const Text('Consent'),
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => ChangeNotifierProvider.value(
                              value: context.read<PatientConsentProvider>(),
                              child: PatientConsentScreen(
                                patientId: p.id,
                                patientName: p.fullName,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Allergies
          if (p.hasAllergies) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              child: _SectionHeader(
                'Allergies',
                badge: p.hasCriticalAllergies ? 'CRITICAL' : null,
              ),
            ),
            AdaptiveCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: p.allergies.map((a) {
                  final isSerious = a.isLifeThreatening || a.isSevere;
                  return AdaptiveListRow(
                    leading: Icon(
                      Icons.warning_rounded,
                      color: isSerious ? tokens.critical : tokens.warning,
                    ),
                    title: a.name,
                    subtitle: a.severity.replaceAll('_', ' ').toUpperCase(),
                    trailing: AdaptiveBadge(
                      label: a.severity.replaceAll('_', ' '),
                      variant: isSerious
                          ? BadgeVariant.critical
                          : BadgeVariant.warning,
                    ),
                  );
                }).toList(),
              ),
            ),
          ],

          // Current medications
          if (p.currentMedications.isNotEmpty) ...[
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              child: _SectionHeader('Current Medications'),
            ),
            AdaptiveCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: p.currentMedications
                    .map(
                      (m) => AdaptiveListRow(
                        leading: Icon(
                          Icons.medication,
                          color: tokens.accent,
                        ),
                        title: m.name,
                        subtitle: m.displayDose,
                      ),
                    )
                    .toList(),
              ),
            ),
          ],

          // Chronic conditions
          if (p.chronicConditions.isNotEmpty) ...[
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              child: _SectionHeader('Chronic Conditions'),
            ),
            AdaptiveCard(
              child: Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: p.chronicConditions
                    .map((c) => AdaptiveBadge(label: c, variant: BadgeVariant.neutral))
                    .toList(),
              ),
            ),
          ],

          // Medical history (free-text narrative)
          if (p.medicalHistory != null && p.medicalHistory!.isNotEmpty) ...[
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              child: _SectionHeader('Medical History'),
            ),
            AdaptiveCard(
              child: Text(
                p.medicalHistory!,
                style: TextStyle(
                  fontSize: 13,
                  height: 1.5,
                  color: tokens.textPrimary,
                ),
              ),
            ),
          ],

          // Emergency contact
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: _SectionHeader('Emergency Contact', icon: Icons.emergency),
          ),
          AdaptiveCard(
            child: Column(
              children: [
                _InfoRow('Name', p.emergencyContactName),
                _InfoRow('Phone', p.emergencyContactPhone),
              ],
            ),
          ),

          // Insurance
          if (p.insuranceProvider != null) ...[
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              child: _SectionHeader('Insurance'),
            ),
            AdaptiveCard(
              child: Column(
                children: [
                  _InfoRow('Provider', p.insuranceProvider!),
                  if (p.insuranceNumber != null)
                    _InfoRow('Number', p.insuranceNumber!),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Appointments Tab ──────────────────────────────────────────────────────────

class _AppointmentsTab extends StatelessWidget {
  final String patientId;
  const _AppointmentsTab({required this.patientId});

  @override
  Widget build(BuildContext context) {
    final appointments = context.watch<ClinicalProvider>().appointments;
    if (appointments.isEmpty) {
      return _EmptyState(
        icon: Icons.calendar_today,
        message: 'No appointments',
      );
    }
    return RefreshIndicator(
      onRefresh: () => context.read<ClinicalProvider>().loadAppointments(),
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
        itemCount: appointments.length,
        itemBuilder: (context, i) => _AppointmentCard(appt: appointments[i]),
      ),
    );
  }
}

class _AppointmentCard extends StatefulWidget {
  final AppointmentModel appt;
  const _AppointmentCard({required this.appt});

  @override
  State<_AppointmentCard> createState() => _AppointmentCardState();
}

class _AppointmentCardState extends State<_AppointmentCard> {
  bool _cancelling = false;
  bool _completing = false;

  Future<void> _cancel() async {
    final reasonCtrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel Appointment'),
        content: TextField(
          controller: reasonCtrl,
          decoration: const InputDecoration(labelText: 'Reason (optional)'),
        ),
        actions: [
          AdaptiveTextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('No'),
          ),
          AdaptiveFilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Cancel Appointment'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _cancelling = true);
    final ok = await context.read<ClinicalProvider>().cancelAppointment(
      widget.appt.id,
      reason: reasonCtrl.text.trim().isEmpty ? null : reasonCtrl.text.trim(),
    );
    if (!mounted) return;
    setState(() => _cancelling = false);

    showAdaptiveToast(
      context,
      ok
          ? 'Appointment cancelled'
          : context.read<ClinicalProvider>().error ?? 'Failed to cancel',
      type: ok ? ToastType.success : ToastType.error,
    );
  }

  Future<void> _complete() async {
    final notesCtrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Complete Appointment'),
        content: TextField(
          controller: notesCtrl,
          maxLines: 3,
          decoration: const InputDecoration(labelText: 'Notes (optional)'),
        ),
        actions: [
          AdaptiveTextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          AdaptiveFilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Mark Complete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _completing = true);
    final ok = await context.read<ClinicalProvider>().completeAppointment(
      widget.appt.id,
      notes: notesCtrl.text.trim().isEmpty ? null : notesCtrl.text.trim(),
    );
    if (!mounted) return;
    setState(() => _completing = false);

    showAdaptiveToast(
      context,
      ok
          ? 'Appointment marked complete'
          : context.read<ClinicalProvider>().error ?? 'Failed to complete',
      type: ok ? ToastType.success : ToastType.error,
    );
  }

  @override
  Widget build(BuildContext context) {
    final appt = widget.appt;
    final tokens = AppColors.of(context);
    final auth = context.read<AuthProvider>();
    final canModify =
        (auth.currentUser?.isSuperAdmin ?? false) ||
        auth.currentUserId == appt.providerId;
    final isOpen = !['completed', 'cancelled', 'no_show'].contains(appt.status);
    final canCancel = canModify && isOpen;
    final canComplete = canModify && isOpen;

    BadgeVariant statusVariant;
    switch (appt.status) {
      case 'completed':
        statusVariant = BadgeVariant.success;
        break;
      case 'cancelled':
      case 'no_show':
        statusVariant = BadgeVariant.critical;
        break;
      case 'checked_in':
        statusVariant = BadgeVariant.accent;
        break;
      default:
        statusVariant = BadgeVariant.warning;
    }

    final dt = appt.appointmentDate;
    final dateStr =
        '${dt.day}/${dt.month}/${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';

    return AdaptiveCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      appt.appointmentType.replaceAll('_', ' ').toUpperCase(),
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: tokens.textPrimary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      dateStr,
                      style: TextStyle(
                        color: tokens.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                    if (appt.reason != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        appt.reason!,
                        style: TextStyle(
                          fontSize: 12,
                          color: tokens.textSecondary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              AdaptiveBadge(
                label: appt.status.replaceAll('_', ' '),
                variant: statusVariant,
              ),
            ],
          ),
          if (canCancel || canComplete) ...[
            const SizedBox(height: AppSpacing.md),
            Wrap(
              spacing: AppSpacing.sm,
              children: [
                if (canComplete)
                  OutlinedButton.icon(
                    onPressed: _completing ? null : _complete,
                    icon: _completing
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.check_circle_outline, size: 16),
                    label: Text(_completing ? 'Saving…' : 'Mark Complete'),
                  ),
                if (canCancel)
                  OutlinedButton.icon(
                    onPressed: _cancelling ? null : _cancel,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: tokens.critical,
                    ),
                    icon: _cancelling
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.event_busy, size: 16),
                    label: Text(_cancelling ? 'Cancelling…' : 'Cancel'),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

// ── Prescriptions Tab ─────────────────────────────────────────────────────────

class _PrescriptionsTab extends StatelessWidget {
  final String patientId;
  const _PrescriptionsTab({required this.patientId});

  @override
  Widget build(BuildContext context) {
    final prescriptions = context.watch<ClinicalProvider>().prescriptions;
    if (prescriptions.isEmpty) {
      return _EmptyState(icon: Icons.medication, message: 'No prescriptions');
    }
    return RefreshIndicator(
      onRefresh: () => context.read<ClinicalProvider>().loadPrescriptions(),
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
        itemCount: prescriptions.length,
        itemBuilder: (context, i) => _PrescriptionCard(rx: prescriptions[i]),
      ),
    );
  }
}

class _PrescriptionCard extends StatefulWidget {
  final PrescriptionModel rx;
  const _PrescriptionCard({required this.rx});

  @override
  State<_PrescriptionCard> createState() => _PrescriptionCardState();
}

class _PrescriptionCardState extends State<_PrescriptionCard> {
  bool _filling = false;
  bool _refilling = false;
  bool _printing = false;

  Future<void> _refill() async {
    setState(() => _refilling = true);
    final result = await context.read<ClinicalProvider>().refillPrescription(
      widget.rx.id,
    );
    if (!mounted) return;
    setState(() => _refilling = false);

    showAdaptiveToast(
      context,
      result != null
          ? 'Refill issued — ${result.refillsRemaining} remaining'
          : context.read<ClinicalProvider>().error ?? 'Failed to issue refill',
      type: result != null ? ToastType.success : ToastType.error,
    );
  }

  Future<void> _print() async {
    setState(() => _printing = true);
    final payload = await context.read<ClinicalProvider>().printPrescription(
      widget.rx.id,
    );
    if (!mounted) return;
    setState(() => _printing = false);

    if (payload == null) {
      showAdaptiveToast(
        context,
        context.read<ClinicalProvider>().error ??
            'Failed to load print payload',
        type: ToastType.error,
      );
      return;
    }
    await showDialog<void>(
      context: context,
      builder: (ctx) => _PrescriptionPrintDialog(payload: payload),
    );
  }

  Future<void> _showEditDialog() async {
    final dosageCtrl = TextEditingController(text: widget.rx.dosage);
    final frequencyCtrl = TextEditingController(text: widget.rx.frequency);
    final instructionsCtrl = TextEditingController(
      text: widget.rx.specialInstructions ?? '',
    );

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit Prescription'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: dosageCtrl,
              decoration: const InputDecoration(labelText: 'Dosage'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: frequencyCtrl,
              decoration: const InputDecoration(labelText: 'Frequency'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: instructionsCtrl,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Special instructions',
              ),
            ),
          ],
        ),
        actions: [
          AdaptiveTextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          AdaptiveFilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    final result = await context
        .read<ClinicalProvider>()
        .updatePrescription(widget.rx.id, {
          'dosage': dosageCtrl.text.trim(),
          'frequency': frequencyCtrl.text.trim(),
          'special_instructions': instructionsCtrl.text.trim().isEmpty
              ? null
              : instructionsCtrl.text.trim(),
        });
    if (!mounted) return;

    showAdaptiveToast(
      context,
      result != null
          ? 'Prescription updated'
          : context.read<ClinicalProvider>().error ??
                'Failed to update prescription',
      type: result != null ? ToastType.success : ToastType.error,
    );
  }

  Future<void> _showFillDialog() async {
    final qtyCtrl = TextEditingController(
      text: widget.rx.quantity?.toString() ?? '',
    );
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Dispense Medication'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.rx.medicationName,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              widget.rx.doseDisplay,
              style: TextStyle(
                color: AppColors.of(context).textSecondary,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: qtyCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Quantity dispensed',
              ),
            ),
          ],
        ),
        actions: [
          AdaptiveTextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          AdaptiveFilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Dispense'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;
    final qty = int.tryParse(qtyCtrl.text.trim());
    if (qty == null || qty <= 0) {
      showAdaptiveToast(
        context,
        'Enter a valid quantity',
        type: ToastType.error,
      );
      return;
    }

    setState(() => _filling = true);
    final result = await context.read<ClinicalProvider>().fillPrescription(
      widget.rx.id,
      qty,
    );
    if (!mounted) return;
    setState(() => _filling = false);

    showAdaptiveToast(
      context,
      result != null
          ? 'Dispensed successfully'
          : context.read<ClinicalProvider>().error ?? 'Failed to dispense',
      type: result != null ? ToastType.success : ToastType.error,
    );
  }

  @override
  Widget build(BuildContext context) {
    final rx = widget.rx;
    final tokens = AppColors.of(context);
    final auth = context.read<AuthProvider>();
    final isPharmacist = auth.staffType == 'pharmacist';
    final canFill =
        isPharmacist &&
        (rx.status == 'pending' || rx.status == 'partially_filled');
    final isOpen = !['cancelled', 'discontinued'].contains(rx.status);
    final canRefill = auth.canPrescribe && rx.refillsRemaining > 0 && isOpen;
    final canEdit =
        isOpen &&
        ((auth.currentUser?.isSuperAdmin ?? false) ||
            auth.currentUserId == rx.prescriberId);
    final canPrint = auth.canPrescribe;
    final statusVariant = rx.isActive
        ? BadgeVariant.success
        : BadgeVariant.neutral;

    return AdaptiveCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.medication, color: tokens.accent, size: 20),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  rx.medicationName,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: tokens.textPrimary,
                  ),
                ),
              ),
              AdaptiveBadge(label: rx.status, variant: statusVariant),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            rx.doseDisplay,
            style: TextStyle(fontSize: 13, color: tokens.textSecondary),
          ),
          if (rx.refillsRemaining > 0) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              '${rx.refillsRemaining} refill(s) remaining',
              style: TextStyle(fontSize: 12, color: tokens.textSecondary),
            ),
          ],
          if (rx.specialInstructions != null) ...[
            const SizedBox(height: AppSpacing.xs + 2),
            Text(
              rx.specialInstructions!,
              style: TextStyle(
                fontSize: 12,
                color: tokens.warning,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
          if (canFill) ...[
            const SizedBox(height: AppSpacing.md),
            SizedBox(
              width: double.infinity,
              child: AdaptiveFilledButton(
                onPressed: _filling ? null : _showFillDialog,
                icon: _filling
                    ? SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation(
                            tokens.onAccent,
                          ),
                        ),
                      )
                    : const Icon(Icons.local_pharmacy, size: 16),
                child: Text(_filling ? 'Dispensing…' : 'Dispense / Fill'),
              ),
            ),
          ],
          if (canRefill || canEdit || canPrint) ...[
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.sm,
              children: [
                if (canRefill)
                  OutlinedButton.icon(
                    onPressed: _refilling ? null : _refill,
                    icon: _refilling
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.autorenew, size: 16),
                    label: Text(_refilling ? 'Refilling…' : 'Refill'),
                  ),
                if (canEdit)
                  OutlinedButton.icon(
                    onPressed: _showEditDialog,
                    icon: const Icon(Icons.edit_outlined, size: 16),
                    label: const Text('Edit'),
                  ),
                if (canPrint)
                  OutlinedButton.icon(
                    onPressed: _printing ? null : _print,
                    icon: _printing
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.print_outlined, size: 16),
                    label: Text(_printing ? 'Loading…' : 'Print'),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _PrescriptionPrintDialog extends StatelessWidget {
  final Map<String, dynamic> payload;
  const _PrescriptionPrintDialog({required this.payload});

  String get _formatted {
    final facility = payload['facility'] as Map?;
    final patient = payload['patient'] as Map?;
    final rx = payload['prescription'] as Map?;
    final buffer = StringBuffer();
    if (facility != null) {
      buffer.writeln(facility['name'] ?? '');
      if (facility['address'] != null) buffer.writeln(facility['address']);
      if (facility['phone'] != null) buffer.writeln(facility['phone']);
      buffer.writeln('');
    }
    buffer.writeln('Patient: ${patient?['name'] ?? ''}');
    if (patient?['date_of_birth'] != null) {
      buffer.writeln('DOB: ${patient?['date_of_birth']}');
    }
    if (patient?['mrn'] != null) buffer.writeln('MRN: ${patient?['mrn']}');
    buffer.writeln('');
    buffer.writeln('Medication: ${rx?['medication_name'] ?? ''}');
    buffer.writeln('Dosage: ${rx?['dosage'] ?? ''}');
    buffer.writeln('Frequency: ${rx?['frequency'] ?? ''}');
    if (rx?['route'] != null) buffer.writeln('Route: ${rx?['route']}');
    if (rx?['quantity'] != null) buffer.writeln('Quantity: ${rx?['quantity']}');
    if (rx?['refills_allowed'] != null) {
      buffer.writeln('Refills allowed: ${rx?['refills_allowed']}');
    }
    if (rx?['special_instructions'] != null) {
      buffer.writeln('Instructions: ${rx?['special_instructions']}');
    }
    buffer.writeln('Status: ${rx?['status'] ?? ''}');
    buffer.writeln('');
    buffer.writeln('Printed: ${payload['printed_at'] ?? ''}');
    return buffer.toString();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Prescription'),
      content: SingleChildScrollView(
        child: Text(
          _formatted,
          style: const TextStyle(fontFamily: 'monospace'),
        ),
      ),
      actions: [
        AdaptiveTextButton(
          onPressed: () async {
            await Clipboard.setData(ClipboardData(text: _formatted));
            if (context.mounted) {
              showAdaptiveToast(
                context,
                'Copied to clipboard',
                type: ToastType.success,
              );
            }
          },
          child: const Text('Copy'),
        ),
        AdaptiveFilledButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ],
    );
  }
}

// ── Lab Results Tab ───────────────────────────────────────────────────────────

class _LabResultsTab extends StatelessWidget {
  final String patientId;
  const _LabResultsTab({required this.patientId});

  @override
  Widget build(BuildContext context) {
    final labs = context.watch<ClinicalProvider>().labResults;
    if (labs.isEmpty) {
      return _EmptyState(icon: Icons.science, message: 'No lab results');
    }
    return RefreshIndicator(
      onRefresh: () => context.read<ClinicalProvider>().loadLabResults(),
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
        itemCount: labs.length,
        itemBuilder: (context, i) => _LabResultCard(lab: labs[i]),
      ),
    );
  }
}

class _LabResultCard extends StatefulWidget {
  final LabResultModel lab;
  const _LabResultCard({required this.lab});

  @override
  State<_LabResultCard> createState() => _LabResultCardState();
}

class _LabResultCardState extends State<_LabResultCard> {
  bool _recording = false;
  bool _cancelling = false;
  bool _printing = false;
  bool _reviewing = false;

  Future<void> _cancel() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel Lab Test'),
        content: Text(
          'Cancel the "${widget.lab.testName}" order? This cannot be undone.',
        ),
        actions: [
          AdaptiveTextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('No'),
          ),
          AdaptiveFilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Cancel Test'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _cancelling = true);
    final result = await context.read<ClinicalProvider>().cancelLabResult(
      widget.lab.id,
    );
    if (!mounted) return;
    setState(() => _cancelling = false);

    showAdaptiveToast(
      context,
      result != null
          ? 'Lab test cancelled'
          : context.read<ClinicalProvider>().error ?? 'Failed to cancel test',
      type: result != null ? ToastType.success : ToastType.error,
    );
  }

  Future<void> _print() async {
    setState(() => _printing = true);
    final payload = await context.read<ClinicalProvider>().printLabOrder(
      widget.lab.id,
    );
    if (!mounted) return;
    setState(() => _printing = false);

    if (payload == null) {
      showAdaptiveToast(
        context,
        context.read<ClinicalProvider>().error ??
            'Failed to load print payload',
        type: ToastType.error,
      );
      return;
    }
    await showDialog<void>(
      context: context,
      builder: (ctx) => _LabOrderPrintDialog(payload: payload),
    );
  }

  Future<void> _review() async {
    final interpretationCtrl = TextEditingController();
    bool requiresFollowup = widget.lab.requiresFollowup;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: const Text('Review Lab Results'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (widget.lab.results != null) ...[
                Text(widget.lab.results!, style: const TextStyle(fontSize: 13)),
                const SizedBox(height: 16),
              ],
              TextField(
                controller: interpretationCtrl,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Interpretation (optional)',
                ),
              ),
              const SizedBox(height: 8),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text(
                  'Requires follow-up',
                  style: TextStyle(fontSize: 13),
                ),
                value: requiresFollowup,
                onChanged: (v) => setLocal(() => requiresFollowup = v ?? false),
              ),
            ],
          ),
          actions: [
            AdaptiveTextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel'),
            ),
            AdaptiveFilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Mark Reviewed'),
            ),
          ],
        ),
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _reviewing = true);
    final result = await context.read<ClinicalProvider>().reviewLabResult(
      widget.lab.id,
      interpretation: interpretationCtrl.text.trim().isEmpty
          ? null
          : interpretationCtrl.text.trim(),
      requiresFollowup: requiresFollowup,
    );
    if (!mounted) return;
    setState(() => _reviewing = false);

    showAdaptiveToast(
      context,
      result != null
          ? 'Results reviewed'
          : context.read<ClinicalProvider>().error ??
                'Failed to review results',
      type: result != null ? ToastType.success : ToastType.error,
    );
  }

  Future<void> _showRecordDialog() async {
    final resultsCtrl = TextEditingController();
    final interpretationCtrl = TextEditingController();
    final flagsCtrl = TextEditingController();
    bool requiresFollowup = false;

    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: const Text('Record Lab Results'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.lab.testName,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                if (widget.lab.testType != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    widget.lab.testType!,
                    style: TextStyle(
                      color: AppColors.of(context).textSecondary,
                      fontSize: 13,
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                TextField(
                  controller: resultsCtrl,
                  maxLines: 3,
                  decoration: const InputDecoration(labelText: 'Results *'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: interpretationCtrl,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Interpretation (optional)',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: flagsCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Abnormal flags (comma-separated)',
                    hintText: 'e.g. HIGH_GLUCOSE, LOW_HB',
                  ),
                ),
                const SizedBox(height: 8),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text(
                    'Requires follow-up',
                    style: TextStyle(fontSize: 13),
                  ),
                  value: requiresFollowup,
                  onChanged: (v) =>
                      setLocal(() => requiresFollowup = v ?? false),
                ),
              ],
            ),
          ),
          actions: [
            AdaptiveTextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel'),
            ),
            AdaptiveFilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Submit'),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true || !mounted) return;
    if (resultsCtrl.text.trim().isEmpty) {
      showAdaptiveToast(context, 'Results are required', type: ToastType.error);
      return;
    }

    final flags = flagsCtrl.text
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();

    setState(() => _recording = true);
    final result = await context
        .read<ClinicalProvider>()
        .recordLabResult(widget.lab.id, {
          'results': resultsCtrl.text.trim(),
          if (interpretationCtrl.text.trim().isNotEmpty)
            'interpretation': interpretationCtrl.text.trim(),
          'abnormal_flags': flags,
          'requires_followup': requiresFollowup,
          'sample_collected_at': DateTime.now().toIso8601String(),
        });
    if (!mounted) return;
    setState(() => _recording = false);

    showAdaptiveToast(
      context,
      result != null
          ? 'Results recorded successfully'
          : context.read<ClinicalProvider>().error ??
                'Failed to record results',
      type: result != null ? ToastType.success : ToastType.error,
    );
  }

  @override
  Widget build(BuildContext context) {
    final lab = widget.lab;
    final tokens = AppColors.of(context);
    final auth = context.read<AuthProvider>();
    final isLabTech =
        auth.staffType == 'lab_technician' || auth.staffType == 'lab_tech';
    final canRecord = isLabTech && lab.isPending;
    final isOpen = lab.status != 'completed' && lab.status != 'cancelled';
    final canCancel =
        isOpen &&
        ((auth.currentUser?.isSuperAdmin ?? false) ||
            auth.currentUserId == lab.orderedById);
    final canPrint = auth.canOrderLabs;
    final canReview =
        lab.isCompleted &&
        lab.reviewedById == null &&
        ((auth.currentUser?.isSuperAdmin ?? false) ||
            auth.currentUserId == lab.orderedById);

    BadgeVariant statusVariant;
    switch (lab.status) {
      case 'completed':
        statusVariant = lab.hasAbnormalResults
            ? BadgeVariant.critical
            : BadgeVariant.success;
        break;
      case 'cancelled':
        statusVariant = BadgeVariant.neutral;
        break;
      default:
        statusVariant = BadgeVariant.warning;
    }

    return AdaptiveCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.science, color: tokens.accent, size: 20),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  lab.testName,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: tokens.textPrimary,
                  ),
                ),
              ),
              if (lab.isUrgent) ...[
                AdaptiveBadge(
                  label: lab.priority,
                  variant: BadgeVariant.critical,
                  icon: Icons.priority_high,
                ),
                const SizedBox(width: AppSpacing.xs),
              ],
              AdaptiveBadge(
                label: lab.status.replaceAll('_', ' '),
                variant: statusVariant,
              ),
            ],
          ),
          if (lab.testType != null) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              lab.testType!,
              style: TextStyle(fontSize: 13, color: tokens.textSecondary),
            ),
          ],
          if (lab.results != null && lab.results!.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Results: ${lab.results!}',
              style: TextStyle(fontSize: 13, color: tokens.textPrimary),
            ),
          ],
          if (lab.abnormalFlags.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              children: lab.abnormalFlags
                  .map((f) => AdaptiveBadge(label: f, variant: BadgeVariant.critical))
                  .toList(),
            ),
          ],
          if (lab.requiresFollowup) ...[
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                Icon(Icons.flag, size: 14, color: tokens.warning),
                const SizedBox(width: AppSpacing.xs),
                Text(
                  'Follow-up required',
                  style: TextStyle(fontSize: 12, color: tokens.warning),
                ),
              ],
            ),
          ],
          if (canRecord) ...[
            const SizedBox(height: AppSpacing.md),
            SizedBox(
              width: double.infinity,
              child: AdaptiveFilledButton(
                onPressed: _recording ? null : _showRecordDialog,
                icon: _recording
                    ? SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation(
                            tokens.onAccent,
                          ),
                        ),
                      )
                    : const Icon(Icons.science, size: 16),
                child: Text(_recording ? 'Saving…' : 'Record Results'),
              ),
            ),
          ],
          if (canCancel || canPrint || canReview) ...[
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.sm,
              children: [
                if (canReview)
                  AdaptiveFilledButton(
                    onPressed: _reviewing ? null : _review,
                    icon: _reviewing
                        ? SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation(
                                tokens.onAccent,
                              ),
                            ),
                          )
                        : const Icon(Icons.fact_check_outlined, size: 16),
                    child: Text(_reviewing ? 'Saving…' : 'Review Results'),
                  ),
                if (canCancel)
                  OutlinedButton.icon(
                    onPressed: _cancelling ? null : _cancel,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: tokens.critical,
                    ),
                    icon: _cancelling
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.cancel_outlined, size: 16),
                    label: Text(_cancelling ? 'Cancelling…' : 'Cancel Test'),
                  ),
                if (canPrint)
                  OutlinedButton.icon(
                    onPressed: _printing ? null : _print,
                    icon: _printing
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.print_outlined, size: 16),
                    label: Text(_printing ? 'Loading…' : 'Print'),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _LabOrderPrintDialog extends StatelessWidget {
  final Map<String, dynamic> payload;
  const _LabOrderPrintDialog({required this.payload});

  String get _formatted {
    final facility = payload['facility'] as Map?;
    final patient = payload['patient'] as Map?;
    final order = payload['lab_order'] as Map?;
    final buffer = StringBuffer();
    if (facility != null) {
      buffer.writeln(facility['name'] ?? '');
      if (facility['address'] != null) buffer.writeln(facility['address']);
      if (facility['phone'] != null) buffer.writeln(facility['phone']);
      buffer.writeln('');
    }
    buffer.writeln('Patient: ${patient?['name'] ?? ''}');
    if (patient?['date_of_birth'] != null) {
      buffer.writeln('DOB: ${patient?['date_of_birth']}');
    }
    if (patient?['mrn'] != null) buffer.writeln('MRN: ${patient?['mrn']}');
    buffer.writeln('');
    buffer.writeln('Test: ${order?['test_name'] ?? ''}');
    if (order?['test_type'] != null)
      buffer.writeln('Type: ${order?['test_type']}');
    buffer.writeln('Priority: ${order?['priority'] ?? ''}');
    if (order?['ordered_date'] != null) {
      buffer.writeln('Ordered: ${order?['ordered_date']}');
    }
    buffer.writeln('Status: ${order?['status'] ?? ''}');
    buffer.writeln('');
    buffer.writeln('Printed: ${payload['printed_at'] ?? ''}');
    return buffer.toString();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Lab Order'),
      content: SingleChildScrollView(
        child: Text(
          _formatted,
          style: const TextStyle(fontFamily: 'monospace'),
        ),
      ),
      actions: [
        AdaptiveTextButton(
          onPressed: () async {
            await Clipboard.setData(ClipboardData(text: _formatted));
            if (context.mounted) {
              showAdaptiveToast(
                context,
                'Copied to clipboard',
                type: ToastType.success,
              );
            }
          },
          child: const Text('Copy'),
        ),
        AdaptiveFilledButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ],
    );
  }
}

// ── Documents Tab ─────────────────────────────────────────────────────────────

class _DocumentsTab extends StatelessWidget {
  final String patientId;
  const _DocumentsTab({required this.patientId});

  @override
  Widget build(BuildContext context) {
    final docs = context.watch<ClinicalProvider>().documents;
    if (docs.isEmpty) {
      return _EmptyState(icon: Icons.folder_outlined, message: 'No documents');
    }
    return RefreshIndicator(
      onRefresh: () => context.read<ClinicalProvider>().loadDocuments(),
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
        itemCount: docs.length,
        itemBuilder: (context, i) => _DocumentCard(doc: docs[i]),
      ),
    );
  }
}

class _DocumentCard extends StatefulWidget {
  final MedicalDocumentModel doc;
  const _DocumentCard({required this.doc});

  @override
  State<_DocumentCard> createState() => _DocumentCardState();
}

class _DocumentCardState extends State<_DocumentCard> {
  bool _downloading = false;

  Future<void> _download() async {
    setState(() => _downloading = true);
    final url = await context.read<ClinicalProvider>().getDocumentDownloadUrl(
      widget.doc.id,
    );
    if (!mounted) return;
    setState(() => _downloading = false);

    if (url == null) {
      showAdaptiveToast(
        context,
        'Could not retrieve document URL',
        type: ToastType.error,
      );
      return;
    }

    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        showAdaptiveToast(
          context,
          'Could not open document',
          type: ToastType.error,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final doc = widget.doc;
    final tokens = AppColors.of(context);

    IconData icon;
    if (doc.isPdf) {
      icon = Icons.picture_as_pdf;
    } else if (doc.isImage) {
      icon = Icons.image;
    } else {
      icon = Icons.insert_drive_file;
    }

    return AdaptiveCard(
      child: AdaptiveListRow(
        leading: Container(
          padding: const EdgeInsets.all(AppSpacing.sm),
          decoration: BoxDecoration(
            color: tokens.accentTint,
            borderRadius: BorderRadius.circular(AppRadius.control),
          ),
          child: Icon(icon, color: tokens.accent),
        ),
        title: doc.title,
        subtitle: [
          doc.documentType.replaceAll('_', ' '),
          if (doc.fileSizeDisplay.isNotEmpty) doc.fileSizeDisplay,
          if (doc.isConfidential) 'Confidential',
        ].join(' · '),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (doc.isConfidential)
              Padding(
                padding: const EdgeInsets.only(right: AppSpacing.xs),
                child: Icon(Icons.lock, size: 16, color: tokens.warning),
              ),
            _downloading
                ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: tokens.accent,
                    ),
                  )
                : IconButton(
                    icon: const Icon(Icons.download_outlined, size: 22),
                    color: tokens.accent,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    tooltip: 'View / Download',
                    onPressed: _download,
                  ),
          ],
        ),
      ),
    );
  }
}

// ── Shared helpers ────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String title;
  final String? badge;
  final IconData? icon;

  const _SectionHeader(this.title, {this.badge, this.icon});

  @override
  Widget build(BuildContext context) {
    final tokens = AppColors.of(context);
    return Padding(
      padding: const EdgeInsets.only(
        top: AppSpacing.sm,
        bottom: AppSpacing.sm,
      ),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, size: 18, color: tokens.textSecondary),
            const SizedBox(width: AppSpacing.xs),
          ],
          Text(
            title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: tokens.textPrimary,
            ),
          ),
          if (badge != null) ...[
            const SizedBox(width: AppSpacing.sm),
            AdaptiveBadge(label: badge!, variant: BadgeVariant.critical),
          ],
        ],
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
    final tokens = AppColors.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: TextStyle(
                color: tokens.textSecondary,
                fontWeight: FontWeight.w500,
                fontSize: 13,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13,
                color: tokens.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String message;
  const _EmptyState({required this.icon, required this.message});

  @override
  Widget build(BuildContext context) {
    final tokens = AppColors.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              color: tokens.surfaceTint,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 40, color: tokens.textSecondary),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            message,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: tokens.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final tokens = AppColors.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 48, color: tokens.critical),
            const SizedBox(height: AppSpacing.md),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: tokens.textSecondary),
            ),
            const SizedBox(height: AppSpacing.lg),
            AdaptiveFilledButton(
              onPressed: onRetry,
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Notes Tab ─────────────────────────────────────────────────────────────────

class _NotesTab extends StatefulWidget {
  final PatientModel patient;
  const _NotesTab({required this.patient});

  @override
  State<_NotesTab> createState() => _NotesTabState();
}

class _NotesTabState extends State<_NotesTab> {
  List<ClinicalNoteModel> _notes = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final repo = context.read<IntraGrantProvider>().repository;
      _notes = await repo.getPatientNotes(widget.patient.id);
    } catch (e) {
      _error = 'Failed to load notes.';
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = AppColors.of(context);
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, size: 48, color: tokens.critical),
              const SizedBox(height: AppSpacing.md),
              Text(
                _error!,
                style: TextStyle(color: tokens.textSecondary),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.lg),
              AdaptiveFilledButton(
                onPressed: _load,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (_notes.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(AppSpacing.lg),
                decoration: BoxDecoration(
                  color: tokens.surfaceTint,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.notes_outlined,
                  size: 40,
                  color: tokens.textSecondary,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                'No clinical notes',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: tokens.textPrimary,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Consultation responses will appear here once a colleague has reviewed this patient.',
                style: TextStyle(fontSize: 13, color: tokens.textSecondary),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
        itemCount: _notes.length,
        itemBuilder: (_, i) => _ClinicalNoteCard(note: _notes[i]),
      ),
    );
  }
}

class _ClinicalNoteCard extends StatelessWidget {
  final ClinicalNoteModel note;
  const _ClinicalNoteCard({required this.note});

  @override
  Widget build(BuildContext context) {
    final tokens = AppColors.of(context);
    final isResponse = note.isConsultationResponse;
    final isDeclined = note.isConsultationDeclined;
    final accentColor = isDeclined ? tokens.warning : tokens.success;
    final bgColor = isDeclined ? tokens.warningTint : tokens.successTint;

    return AdaptiveCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isResponse
                    ? Icons.check_circle_outline
                    : isDeclined
                    ? Icons.cancel_outlined
                    : Icons.notes_outlined,
                size: 18,
                color: isResponse || isDeclined
                    ? accentColor
                    : tokens.accent,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  note.displayTitle,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                    color: tokens.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            '${note.authoredByName}  ·  ${_fmtDate(note.authoredAt)}',
            style: TextStyle(fontSize: 11, color: tokens.textSecondary),
          ),
          Divider(height: AppSpacing.xl, color: tokens.surfaceBorder),
          if (isResponse || isDeclined)
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(AppRadius.control),
                border: Border.all(color: accentColor.withValues(alpha: 0.35)),
              ),
              child: Text(
                note.body,
                style: TextStyle(
                  fontSize: 13,
                  height: 1.5,
                  color: tokens.textPrimary,
                ),
              ),
            )
          else
            Text(
              note.body,
              style: TextStyle(
                fontSize: 13,
                height: 1.5,
                color: tokens.textPrimary,
              ),
            ),
        ],
      ),
    );
  }

  String _fmtDate(DateTime dt) =>
      '${dt.day.toString().padLeft(2, '0')}/'
      '${dt.month.toString().padLeft(2, '0')}/'
      '${dt.year}';
}

// ── Ward Tab — admission, transfer, and discharge request workflows ────────

class _WardTab extends StatelessWidget {
  final String patientId;

  const _WardTab({required this.patientId});

  @override
  Widget build(BuildContext context) {
    return Consumer<WardWorkflowProvider>(
      builder: (context, ward, _) {
        if (ward.isLoading && ward.admissionRequests.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }
        final tokens = AppColors.of(context);
        return RefreshIndicator(
          onRefresh: () => ward.loadAll(patientId),
          child: ListView(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
            children: [
              if (ward.error != null)
                AdaptiveCard(
                  backgroundColor: tokens.criticalTint,
                  borderColor: tokens.criticalBorder,
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.sm,
                  ),
                  child: Text(
                    ward.error!,
                    style: TextStyle(color: tokens.critical, fontSize: 12),
                  ),
                ),
              _WardSection(
                title: 'Admission Requests',
                onRequest: () => _openSheet(
                  context,
                  RequestAdmissionSheet(
                    patientId: patientId,
                    wards: ward.wards,
                  ),
                ),
                onForce: () => _openSheet(
                  context,
                  RequestAdmissionSheet(
                    patientId: patientId,
                    wards: ward.wards,
                    force: true,
                  ),
                ),
                children: ward.admissionRequests.isEmpty
                    ? [const _EmptyHint(text: 'No admission requests yet.')]
                    : ward.admissionRequests
                          .map(
                            (r) => _AdmissionCard(
                              patientId: patientId,
                              request: r,
                            ),
                          )
                          .toList(),
              ),
              const SizedBox(height: AppSpacing.xl),
              _WardSection(
                title: 'Transfer Requests',
                onRequest: () => _openSheet(
                  context,
                  RequestTransferSheet(patientId: patientId, wards: ward.wards),
                ),
                onForce: () => _openSheet(
                  context,
                  RequestTransferSheet(
                    patientId: patientId,
                    wards: ward.wards,
                    force: true,
                  ),
                ),
                children: ward.transferRequests.isEmpty
                    ? [const _EmptyHint(text: 'No transfer requests yet.')]
                    : ward.transferRequests
                          .map(
                            (r) =>
                                _TransferCard(patientId: patientId, request: r),
                          )
                          .toList(),
              ),
              const SizedBox(height: AppSpacing.xl),
              _WardSection(
                title: 'Discharge',
                onRequest: () => _openSheet(
                  context,
                  RequestDischargeSheet(patientId: patientId),
                ),
                onForce: () => _openSheet(
                  context,
                  RequestDischargeSheet(patientId: patientId, force: true),
                ),
                children: ward.dischargeRequests.isEmpty
                    ? [const _EmptyHint(text: 'No discharge requests yet.')]
                    : ward.dischargeRequests
                          .map(
                            (r) => _DischargeCard(
                              patientId: patientId,
                              request: r,
                            ),
                          )
                          .toList(),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _openSheet(BuildContext context, Widget sheet) async {
    final provider = context.read<WardWorkflowProvider>();
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) =>
          ChangeNotifierProvider.value(value: provider, child: sheet),
    );
  }
}

class _WardSection extends StatelessWidget {
  final String title;
  final VoidCallback onRequest;
  final VoidCallback onForce;
  final List<Widget> children;

  const _WardSection({
    required this.title,
    required this.onRequest,
    required this.onForce,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = AppColors.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    color: tokens.textPrimary,
                  ),
                ),
              ),
              TextButton(onPressed: onForce, child: const Text('Force')),
              FilledButton.tonal(
                onPressed: onRequest,
                child: const Text('Request'),
              ),
            ],
          ),
        ),
        ...children,
      ],
    );
  }
}

class _EmptyHint extends StatelessWidget {
  final String text;
  const _EmptyHint({required this.text});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(
      horizontal: AppSpacing.lg,
      vertical: AppSpacing.md,
    ),
    child: Text(
      text,
      style: TextStyle(color: AppColors.of(context).textSecondary, fontSize: 13),
    ),
  );
}

class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final variant = switch (status) {
      'pending' => BadgeVariant.warning,
      'accepted' || 'records_approved' => BadgeVariant.accent,
      'rejected' => BadgeVariant.critical,
      'cancelled' => BadgeVariant.neutral,
      'discharged' => BadgeVariant.success,
      _ => BadgeVariant.neutral,
    };
    return AdaptiveBadge(
      label: status.replaceAll('_', ' '),
      variant: variant,
    );
  }
}

class _AdmissionCard extends StatelessWidget {
  final String patientId;
  final AdmissionRequestModel request;

  const _AdmissionCard({required this.patientId, required this.request});

  @override
  Widget build(BuildContext context) {
    final tokens = AppColors.of(context);
    final provider = context.read<WardWorkflowProvider>();
    return AdaptiveCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${request.admissionType[0].toUpperCase()}${request.admissionType.substring(1)} admission',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: tokens.textPrimary,
                  ),
                ),
              ),
              _StatusBadge(status: request.status),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            request.reason,
            style: TextStyle(fontSize: 13, color: tokens.textPrimary),
          ),
          if (request.rejectionReason != null) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Rejected: ${request.rejectionReason}',
              style: TextStyle(fontSize: 12, color: tokens.critical),
            ),
          ],
          if (request.isPending) ...[
            const SizedBox(height: AppSpacing.sm),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () async {
                    final reason = await showReasonPrompt(
                      context,
                      title: 'Reject admission request',
                    );
                    if (reason != null) {
                      provider.rejectAdmission(patientId, request.id, reason);
                    }
                  },
                  child: const Text('Reject'),
                ),
                const SizedBox(width: AppSpacing.xs),
                FilledButton(
                  onPressed: () =>
                      provider.acceptAdmission(patientId, request.id),
                  child: const Text('Accept'),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _TransferCard extends StatelessWidget {
  final String patientId;
  final WardTransferRequestModel request;

  const _TransferCard({required this.patientId, required this.request});

  @override
  Widget build(BuildContext context) {
    final tokens = AppColors.of(context);
    final provider = context.read<WardWorkflowProvider>();
    return AdaptiveCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Ward transfer',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: tokens.textPrimary,
                  ),
                ),
              ),
              _StatusBadge(status: request.status),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            request.reason,
            style: TextStyle(fontSize: 13, color: tokens.textPrimary),
          ),
          if (request.rejectionReason != null) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Rejected: ${request.rejectionReason}',
              style: TextStyle(fontSize: 12, color: tokens.critical),
            ),
          ],
          if (request.isPending) ...[
            const SizedBox(height: AppSpacing.sm),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () async {
                    final reason = await showReasonPrompt(
                      context,
                      title: 'Reject transfer request',
                    );
                    if (reason != null) {
                      provider.rejectTransfer(patientId, request.id, reason);
                    }
                  },
                  child: const Text('Reject'),
                ),
                const SizedBox(width: AppSpacing.xs),
                FilledButton(
                  onPressed: () =>
                      provider.acceptTransfer(patientId, request.id),
                  child: const Text('Accept'),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _DischargeCard extends StatelessWidget {
  final String patientId;
  final DischargeRequestModel request;

  const _DischargeCard({required this.patientId, required this.request});

  @override
  Widget build(BuildContext context) {
    final tokens = AppColors.of(context);
    final provider = context.read<WardWorkflowProvider>();
    return AdaptiveCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  request.dischargeType.replaceAll('_', ' '),
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: tokens.textPrimary,
                  ),
                ),
              ),
              _StatusBadge(status: request.status),
            ],
          ),
          if (request.dischargeSummary != null) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              request.dischargeSummary!,
              style: TextStyle(fontSize: 13, color: tokens.textPrimary),
            ),
          ],
          if (request.signoffs.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Divider(height: 1, color: tokens.surfaceBorder),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Sign-offs',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: tokens.textPrimary,
              ),
            ),
            ...request.signoffs.map(
              (s) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        s.departmentType,
                        style: TextStyle(
                          fontSize: 12,
                          color: tokens.textPrimary,
                        ),
                      ),
                    ),
                    _StatusBadge(status: s.status),
                    if (s.status == 'pending') ...[
                      const SizedBox(width: AppSpacing.xs),
                      IconButton(
                        icon: Icon(
                          Icons.check,
                          size: 18,
                          color: tokens.success,
                        ),
                        tooltip: 'Approve',
                        onPressed: () => provider.approveSignoff(
                          patientId,
                          request.id,
                          s.id,
                        ),
                      ),
                      IconButton(
                        icon: Icon(
                          Icons.close,
                          size: 18,
                          color: tokens.critical,
                        ),
                        tooltip: 'Reject',
                        onPressed: () async {
                          final reason = await showReasonPrompt(
                            context,
                            title: 'Reject sign-off',
                          );
                          if (reason != null) {
                            provider.rejectSignoff(
                              patientId,
                              request.id,
                              s.id,
                              reason,
                            );
                          }
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.gpp_maybe_outlined, size: 18),
                        tooltip: 'Override',
                        onPressed: () async {
                          final reason = await showReasonPrompt(
                            context,
                            title: 'Override sign-off',
                            label: 'Override reason',
                          );
                          if (reason != null) {
                            provider.overrideSignoff(
                              patientId,
                              request.id,
                              s.id,
                              reason,
                            );
                          }
                        },
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
          if (request.canRecordsApprove || request.canExecute) ...[
            const SizedBox(height: AppSpacing.sm),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (request.canRecordsApprove)
                  FilledButton.tonal(
                    onPressed: () =>
                        provider.recordsApprove(patientId, request.id),
                    child: const Text('Records Approve'),
                  ),
                if (request.canExecute) ...[
                  const SizedBox(width: AppSpacing.sm),
                  FilledButton(
                    onPressed: () =>
                        provider.executeDischarge(patientId, request.id),
                    child: const Text('Discharge Now'),
                  ),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }
}
