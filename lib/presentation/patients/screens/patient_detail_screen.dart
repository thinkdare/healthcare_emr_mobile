import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/platform.dart';
import '../../../data/models/patient_models.dart';
import '../../../data/models/clinical_models.dart';
import '../../../data/providers/auth_provider.dart';
import '../../../data/providers/clinical_provider.dart';
import '../../../data/providers/patient_provider.dart';
import '../../../data/providers/referral_provider.dart';
import '../../access_grants/widgets/transfer_request_sheet.dart';
import '../../referrals/widgets/create_referral_sheet.dart';
import '../widgets/clinical_forms.dart';
import '../widgets/clinical_record_tab.dart';
import '../widgets/clinical_record_forms.dart';
import 'patient_audit_log_screen.dart';
import 'patient_form_screen.dart';
import 'patient_messages_screen.dart';
import '../../../config/app_colors.dart';
import '../../shared/widgets/critical_alert_card.dart';
import '../../shared/widgets/adaptive_card.dart';
import '../../shared/widgets/adaptive_badge.dart';

class PatientDetailScreen extends StatefulWidget {
  final PatientModel patient;

  const PatientDetailScreen({super.key, required this.patient});

  @override
  State<PatientDetailScreen> createState() => _PatientDetailScreenState();
}

// Tabs available to each staff type (by index into _allTabs).
// 0=Overview 1=Appointments 2=Prescriptions 3=Lab Results 4=Documents 5=Clinical Record
const _nurseTabIndices = [0, 1, 5];
const _pharmacistTabIndices = [0, 2];
const _labTechTabIndices = [0, 3];
const _doctorTabIndices = [0, 1, 2, 3, 4, 5];

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

  Future<void> _openTransferSheet() async {
    final transferred = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => TransferRequestSheet(patientId: _patient.id),
    );
    if (transferred == true && mounted) {
      showAdaptiveToast(
        context,
        'Transfer request sent.',
        type: ToastType.success,
      );
    }
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
              if (auth.isStaff)
                CupertinoButton(
                  padding: EdgeInsets.zero,
                  onPressed: _openTransferSheet,
                  child: const Icon(CupertinoIcons.person_2_square_stack),
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
              backgroundColor: AppColors.of(context).accent,
              foregroundColor: Colors.white,
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
          if (auth.isStaff)
            IconButton(
              icon: const Icon(Icons.swap_horiz),
              tooltip: 'Transfer patient',
              onPressed: _openTransferSheet,
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
        ],
        bottom: TabBar(
          controller: _tabs,
          isScrollable: true,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
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

// ── Overview Tab ─────────────────────────────────────────────────────────────

class _OverviewTab extends StatelessWidget {
  final PatientModel patient;
  const _OverviewTab({required this.patient});

  @override
  Widget build(BuildContext context) {
    final p = patient;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      child: Column(
        // Keyed so the safety-invariant test (Task 30) can target this
        // exact Column deterministically — do not remove this key, and do
        // not rely on find.byType(Column).first in any test, since
        // AdaptiveCard/AdaptiveListRow and ancestor widgets (AppBar,
        // Scaffold, TabBarView, AppLockGate) also build Columns.
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
                      backgroundColor: AppColors.of(context).accentTint,
                      child: Text(
                        p.firstName[0] + p.lastName[0],
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: AppColors.of(context).accent,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            p.fullName,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${p.ageDisplay} · ${p.gender} · ${p.bloodType ?? 'Blood type unknown'}',
                            style: TextStyle(
                              color: AppColors.of(context).textSecondary,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const Divider(height: 24),
                if (p.mrn != null) _InfoRow('MRN', p.mrn!),
                _InfoRow('Date of Birth', p.dateOfBirth),
                if (p.phone != null) _InfoRow('Phone', p.phone!),
                if (p.email != null) _InfoRow('Email', p.email!),
                if (p.address != null) _InfoRow('Address', p.address!),
              ],
            ),
          ),
          const SizedBox(height: 16),

          AdaptiveCard(
            padding: EdgeInsets.zero,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => PatientMessagesScreen(
                  patientId: p.id,
                  patientName: p.fullName,
                ),
              ),
            ),
            child: ListTile(
              leading: Icon(
                Icons.chat_bubble_outline,
                color: AppColors.of(context).accent,
              ),
              title: const Text('Messages'),
              subtitle: const Text('Conversation with this patient'),
              trailing: const Icon(Icons.chevron_right),
            ),
          ),
          const SizedBox(height: 16),

          // Audit log — only the primary provider (or a super admin, who
          // won't be logging into this provider-facing app) can view this.
          if (context.watch<AuthProvider>().currentUserId ==
              p.primaryProviderId) ...[
            AdaptiveCard(
              padding: EdgeInsets.zero,
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => PatientAuditLogScreen(
                    patientId: p.id,
                    patientName: p.fullName,
                  ),
                ),
              ),
              child: ListTile(
                leading: Icon(
                  Icons.history,
                  color: AppColors.of(context).accent,
                ),
                title: const Text('Audit Log'),
                subtitle: const Text('Who accessed this patient\'s record'),
                trailing: const Icon(Icons.chevron_right),
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Allergies
          if (p.hasAllergies) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _SectionHeader(
                'Allergies',
                badge: p.hasCriticalAllergies ? 'CRITICAL' : null,
                badgeColor: AppColors.of(context).critical,
              ),
            ),
            AdaptiveCard(
              child: Column(
                children: p.allergies.map((a) {
                  final isSerious = a.isLifeThreatening || a.isSevere;
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                      Icons.warning_rounded,
                      color: isSerious
                          ? AppColors.of(context).critical
                          : AppColors.of(context).warning,
                    ),
                    title: Text(
                      a.name,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text(
                      a.severity.replaceAll('_', ' ').toUpperCase(),
                    ),
                    dense: true,
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Current medications
          if (p.currentMedications.isNotEmpty) ...[
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: _SectionHeader('Current Medications'),
            ),
            AdaptiveCard(
              child: Column(
                children: p.currentMedications
                    .map(
                      (m) => ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(
                          Icons.medication,
                          color: AppColors.of(context).accent,
                        ),
                        title: Text(
                          m.name,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        subtitle: Text(m.displayDose),
                        dense: true,
                      ),
                    )
                    .toList(),
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Chronic conditions
          if (p.chronicConditions.isNotEmpty) ...[
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: _SectionHeader('Chronic Conditions'),
            ),
            AdaptiveCard(
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: p.chronicConditions
                    .map(
                      (c) => Chip(
                        label: Text(c, style: const TextStyle(fontSize: 13)),
                        backgroundColor: AppColors.of(
                          context,
                        ).accent.withValues(alpha: 0.08),
                      ),
                    )
                    .toList(),
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Medical history (free-text narrative)
          if (p.medicalHistory != null && p.medicalHistory!.isNotEmpty) ...[
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: _SectionHeader('Medical History'),
            ),
            AdaptiveCard(
              child: Text(
                p.medicalHistory!,
                style: const TextStyle(fontSize: 13, height: 1.5),
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Emergency contact
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
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
          const SizedBox(height: 16),

          // Insurance
          if (p.insuranceProvider != null) ...[
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
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
        padding: const EdgeInsets.all(16),
        itemCount: appointments.length,
        itemBuilder: (context, i) => _AppointmentCard(appt: appointments[i]),
      ),
    );
  }
}

class _AppointmentCard extends StatelessWidget {
  final AppointmentModel appt;
  const _AppointmentCard({required this.appt});

  @override
  Widget build(BuildContext context) {
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
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  appt.appointmentType.replaceAll('_', ' ').toUpperCase(),
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  dateStr,
                  style: TextStyle(
                    color: AppColors.of(context).textSecondary,
                    fontSize: 13,
                  ),
                ),
                if (appt.reason != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    appt.reason!,
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.of(context).textSecondary,
                    ),
                  ),
                ],
              ],
            ),
          ),
          AdaptiveBadge(
            label: appt.status.replaceAll('_', ' ').toUpperCase(),
            variant: statusVariant,
          ),
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
        padding: const EdgeInsets.all(16),
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
    final isPharmacist = context.read<AuthProvider>().staffType == 'pharmacist';
    final canFill =
        isPharmacist &&
        (rx.status == 'pending' || rx.status == 'partially_filled');
    final statusVariant = rx.isActive
        ? BadgeVariant.success
        : BadgeVariant.neutral;

    return AdaptiveCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.medication,
                color: AppColors.of(context).accent,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  rx.medicationName,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              AdaptiveBadge(
                label: rx.status.toUpperCase(),
                variant: statusVariant,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            rx.doseDisplay,
            style: TextStyle(
              fontSize: 13,
              color: AppColors.of(context).textSecondary,
            ),
          ),
          if (rx.refillsRemaining > 0) ...[
            const SizedBox(height: 4),
            Text(
              '${rx.refillsRemaining} refill(s) remaining',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.of(context).textSecondary,
              ),
            ),
          ],
          if (rx.specialInstructions != null) ...[
            const SizedBox(height: 6),
            Text(
              rx.specialInstructions!,
              style: TextStyle(
                fontSize: 12,
                color: AppColors.of(context).warning,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
          if (canFill) ...[
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: AdaptiveFilledButton(
                onPressed: _filling ? null : _showFillDialog,
                icon: _filling
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation(Colors.white),
                        ),
                      )
                    : const Icon(Icons.local_pharmacy, size: 16),
                child: Text(_filling ? 'Dispensing…' : 'Dispense / Fill'),
              ),
            ),
          ],
        ],
      ),
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
        padding: const EdgeInsets.all(16),
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
    final isLabTech =
        context.read<AuthProvider>().staffType == 'lab_technician' ||
        context.read<AuthProvider>().staffType == 'lab_tech';
    final canRecord = isLabTech && lab.isPending;

    BadgeVariant statusVariant;
    switch (lab.status) {
      case 'completed':
        statusVariant = lab.hasAbnormalResults
            ? BadgeVariant.critical
            : BadgeVariant.success;
        break;
      case 'cancelled':
        statusVariant = BadgeVariant.critical;
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
              Icon(
                Icons.science,
                color: AppColors.of(context).accent,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  lab.testName,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (lab.isUrgent) ...[
                AdaptiveBadge(
                  label: lab.priority.toUpperCase(),
                  variant: BadgeVariant.critical,
                ),
                const SizedBox(width: 6),
              ],
              AdaptiveBadge(
                label: lab.status.replaceAll('_', ' ').toUpperCase(),
                variant: statusVariant,
              ),
            ],
          ),
          if (lab.testType != null) ...[
            const SizedBox(height: 4),
            Text(
              lab.testType!,
              style: TextStyle(
                fontSize: 13,
                color: AppColors.of(context).textSecondary,
              ),
            ),
          ],
          if (lab.results != null && lab.results!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'Results: ${lab.results!}',
              style: const TextStyle(fontSize: 13),
            ),
          ],
          if (lab.abnormalFlags.isNotEmpty) ...[
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              children: lab.abnormalFlags
                  .map(
                    (f) => Chip(
                      label: Text(f, style: const TextStyle(fontSize: 11)),
                      backgroundColor: AppColors.of(
                        context,
                      ).critical.withValues(alpha: 0.1),
                      side: BorderSide(
                        color: AppColors.of(
                          context,
                        ).critical.withValues(alpha: 0.3),
                      ),
                      padding: EdgeInsets.zero,
                    ),
                  )
                  .toList(),
            ),
          ],
          if (lab.requiresFollowup) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                Icon(
                  Icons.flag,
                  size: 14,
                  color: AppColors.of(context).warning,
                ),
                const SizedBox(width: 4),
                Text(
                  'Follow-up required',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.of(context).warning,
                  ),
                ),
              ],
            ),
          ],
          if (canRecord) ...[
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: AdaptiveFilledButton(
                onPressed: _recording ? null : _showRecordDialog,
                icon: _recording
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation(Colors.white),
                        ),
                      )
                    : const Icon(Icons.science, size: 16),
                child: Text(_recording ? 'Saving…' : 'Record Results'),
              ),
            ),
          ],
        ],
      ),
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
        padding: const EdgeInsets.all(16),
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

    IconData icon;
    if (doc.isPdf) {
      icon = Icons.picture_as_pdf;
    } else if (doc.isImage) {
      icon = Icons.image;
    } else {
      icon = Icons.insert_drive_file;
    }

    return AdaptiveCard(
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.of(context).accent.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: AppColors.of(context).accent),
        ),
        title: Text(
          doc.title,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          [
            doc.documentType.replaceAll('_', ' '),
            if (doc.fileSizeDisplay.isNotEmpty) doc.fileSizeDisplay,
          ].join(' · '),
          style: TextStyle(
            fontSize: 12,
            color: AppColors.of(context).textSecondary,
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (doc.isConfidential)
              const Padding(
                padding: EdgeInsets.only(right: 6),
                child: AdaptiveBadge(
                  label: 'Confidential',
                  variant: BadgeVariant.critical,
                ),
              ),
            _downloading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : IconButton(
                    icon: const Icon(Icons.download_outlined, size: 22),
                    color: AppColors.of(context).accent,
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
  final Color? badgeColor;
  final IconData? icon;

  const _SectionHeader(this.title, {this.badge, this.badgeColor, this.icon});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, size: 18, color: AppColors.of(context).textSecondary),
            const SizedBox(width: 6),
          ],
          Text(
            title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          if (badge != null) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: badgeColor ?? AppColors.of(context).critical,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                badge!,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
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
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: TextStyle(
                color: AppColors.of(context).textSecondary,
                fontWeight: FontWeight.w500,
                fontSize: 13,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
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
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 64,
            color: AppColors.of(context).textSecondary.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 12),
          Text(
            message,
            style: TextStyle(
              fontSize: 16,
              color: AppColors.of(context).textSecondary,
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
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.error_outline,
            size: 48,
            color: AppColors.of(context).critical,
          ),
          const SizedBox(height: 12),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.of(context).textSecondary),
          ),
          const SizedBox(height: 16),
          AdaptiveFilledButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}
