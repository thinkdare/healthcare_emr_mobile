import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../config/theme.dart';
import '../../../data/models/patient_models.dart';
import '../../../data/models/clinical_models.dart';
import '../../../data/providers/auth_provider.dart';
import '../../../data/providers/clinical_provider.dart';
import '../../../data/providers/patient_provider.dart';
import '../widgets/clinical_forms.dart';
import 'patient_form_screen.dart';

class PatientDetailScreen extends StatefulWidget {
  final PatientModel patient;

  const PatientDetailScreen({super.key, required this.patient});

  @override
  State<PatientDetailScreen> createState() => _PatientDetailScreenState();
}

class _PatientDetailScreenState extends State<PatientDetailScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  late PatientModel _patient;
  int _currentTab = 0;

  @override
  void initState() {
    super.initState();
    _patient = widget.patient;
    _tabs = TabController(length: 5, vsync: this);
    _tabs.addListener(() {
      if (!_tabs.indexIsChanging) {
        setState(() => _currentTab = _tabs.index);
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ClinicalProvider>().loadAll(_patient.id);
    });
  }

  Future<void> _openClinicalForm() async {
    final auth = context.read<AuthProvider>();
    Widget? form;

    switch (_currentTab) {
      case 1: // Appointments
        form = const AppointmentForm();
        break;
      case 2: // Prescriptions
        if (!auth.canPrescribe) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('You do not have prescribing privileges')),
          );
          return;
        }
        form = const PrescriptionForm();
        break;
      case 3: // Lab Results
        if (!auth.canOrderLabs) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('You do not have lab ordering privileges')),
          );
          return;
        }
        form = const LabOrderForm();
        break;
      default:
        return;
    }

    final created = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => form!,
    );

    if (created == true && mounted) {
      // Reload the relevant list
      final clinical = context.read<ClinicalProvider>();
      switch (_currentTab) {
        case 1:
          clinical.loadAppointments();
          break;
        case 2:
          clinical.loadPrescriptions();
          break;
        case 3:
          clinical.loadLabResults();
          break;
      }
    }
  }

  Future<void> _openEdit() async {
    final updated = await Navigator.of(context).push<PatientModel>(
      MaterialPageRoute(
        builder: (_) => PatientFormScreen(patient: _patient),
      ),
    );
    if (updated != null && mounted) {
      setState(() => _patient = updated);
      // Keep PatientProvider list in sync
      context.read<PatientProvider>().setSelectedPatient(updated);
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
    return Scaffold(
      floatingActionButton: _currentTab >= 1 && _currentTab <= 3
          ? FloatingActionButton(
              onPressed: _openClinicalForm,
              tooltip: switch (_currentTab) {
                1 => 'Book Appointment',
                2 => 'New Prescription',
                3 => 'Order Lab Test',
                _ => 'Add',
              },
              child: const Icon(Icons.add),
            )
          : null,
      appBar: AppBar(
        title: Text(p.fullName),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'Edit patient',
            onPressed: _openEdit,
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: () =>
                context.read<ClinicalProvider>().loadAll(p.id),
          ),
        ],
        bottom: TabBar(
          controller: _tabs,
          isScrollable: true,
          tabs: const [
            Tab(text: 'Overview'),
            Tab(text: 'Appointments'),
            Tab(text: 'Prescriptions'),
            Tab(text: 'Lab Results'),
            Tab(text: 'Documents'),
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
          return TabBarView(
            controller: _tabs,
            children: [
              _OverviewTab(patient: _patient),
              _AppointmentsTab(patientId: _patient.id),
              _PrescriptionsTab(patientId: _patient.id),
              _LabResultsTab(patientId: _patient.id),
              _DocumentsTab(patientId: _patient.id),
            ],
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
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Patient summary card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 32,
                        backgroundColor:
                            AppTheme.primaryColor.withValues(alpha: 0.15),
                        child: Text(
                          p.firstName[0] + p.lastName[0],
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.primaryColor,
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(p.fullName,
                                style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold)),
                            const SizedBox(height: 4),
                            Text(
                              '${p.ageDisplay} · ${p.gender} · ${p.bloodType ?? 'Blood type unknown'}',
                              style: TextStyle(
                                  color: AppTheme.gray600, fontSize: 14),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 24),
                  _InfoRow('Date of Birth', p.dateOfBirth),
                  if (p.phone != null) _InfoRow('Phone', p.phone!),
                  if (p.email != null) _InfoRow('Email', p.email!),
                  if (p.address != null) _InfoRow('Address', p.address!),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Allergies
          if (p.hasAllergies) ...[
            _SectionHeader(
              'Allergies',
              badge: p.hasCriticalAllergies ? 'CRITICAL' : null,
              badgeColor: AppTheme.errorColor,
            ),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: p.allergies.map((a) {
                    final isSerious = a.isLifeThreatening || a.isSevere;
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(
                        Icons.warning_rounded,
                        color: isSerious
                            ? AppTheme.errorColor
                            : AppTheme.warningColor,
                      ),
                      title: Text(a.name,
                          style:
                              const TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: Text(
                          a.severity.replaceAll('_', ' ').toUpperCase()),
                      dense: true,
                    );
                  }).toList(),
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Current medications
          if (p.currentMedications.isNotEmpty) ...[
            const _SectionHeader('Current Medications'),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: p.currentMedications.map((m) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.medication,
                        color: AppTheme.primaryColor),
                    title: Text(m.name,
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text(m.displayDose),
                    dense: true,
                  )).toList(),
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Chronic conditions
          if (p.chronicConditions.isNotEmpty) ...[
            const _SectionHeader('Chronic Conditions'),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: p.chronicConditions.map((c) => Chip(
                    label: Text(c, style: const TextStyle(fontSize: 13)),
                    backgroundColor:
                        AppTheme.primaryColor.withValues(alpha: 0.08),
                  )).toList(),
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Emergency contact
          _SectionHeader('Emergency Contact',
              icon: Icons.emergency),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _InfoRow('Name', p.emergencyContactName),
                  _InfoRow('Phone', p.emergencyContactPhone),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Insurance
          if (p.insuranceProvider != null) ...[
            const _SectionHeader('Insurance'),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    _InfoRow('Provider', p.insuranceProvider!),
                    if (p.insuranceNumber != null)
                      _InfoRow('Number', p.insuranceNumber!),
                  ],
                ),
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
    Color statusColor;
    switch (appt.status) {
      case 'completed':
        statusColor = AppTheme.successColor;
        break;
      case 'cancelled':
      case 'no_show':
        statusColor = AppTheme.gray600;
        break;
      case 'checked_in':
        statusColor = AppTheme.primaryColor;
        break;
      default:
        statusColor = AppTheme.warningColor;
    }

    final dt = appt.appointmentDate;
    final dateStr =
        '${dt.day}/${dt.month}/${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 4,
              height: 56,
              decoration: BoxDecoration(
                color: statusColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    appt.appointmentType.replaceAll('_', ' ').toUpperCase(),
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 2),
                  Text(dateStr,
                      style: TextStyle(
                          color: AppTheme.gray600, fontSize: 13)),
                  if (appt.reason != null) ...[
                    const SizedBox(height: 2),
                    Text(appt.reason!,
                        style: TextStyle(
                            fontSize: 12, color: AppTheme.gray600)),
                  ],
                ],
              ),
            ),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                appt.status.replaceAll('_', ' ').toUpperCase(),
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: statusColor),
              ),
            ),
          ],
        ),
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
      return _EmptyState(
        icon: Icons.medication,
        message: 'No prescriptions',
      );
    }
    return RefreshIndicator(
      onRefresh: () => context.read<ClinicalProvider>().loadPrescriptions(),
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: prescriptions.length,
        itemBuilder: (context, i) =>
            _PrescriptionCard(rx: prescriptions[i]),
      ),
    );
  }
}

class _PrescriptionCard extends StatelessWidget {
  final PrescriptionModel rx;
  const _PrescriptionCard({required this.rx});

  @override
  Widget build(BuildContext context) {
    final color = rx.isActive ? AppTheme.successColor : AppTheme.gray600;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.medication, color: AppTheme.primaryColor, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(rx.medicationName,
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w600)),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    rx.status.toUpperCase(),
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: color),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(rx.doseDisplay,
                style: TextStyle(fontSize: 13, color: AppTheme.gray600)),
            if (rx.refillsRemaining > 0) ...[
              const SizedBox(height: 4),
              Text('${rx.refillsRemaining} refill(s) remaining',
                  style: TextStyle(fontSize: 12, color: AppTheme.gray600)),
            ],
            if (rx.specialInstructions != null) ...[
              const SizedBox(height: 6),
              Text(rx.specialInstructions!,
                  style: TextStyle(
                      fontSize: 12,
                      color: AppTheme.warningColor,
                      fontStyle: FontStyle.italic)),
            ],
          ],
        ),
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
      return _EmptyState(
        icon: Icons.science,
        message: 'No lab results',
      );
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

class _LabResultCard extends StatelessWidget {
  final LabResultModel lab;
  const _LabResultCard({required this.lab});

  @override
  Widget build(BuildContext context) {
    Color statusColor;
    switch (lab.status) {
      case 'completed':
        statusColor =
            lab.hasAbnormalResults ? AppTheme.errorColor : AppTheme.successColor;
        break;
      case 'cancelled':
        statusColor = AppTheme.gray600;
        break;
      default:
        statusColor = AppTheme.warningColor;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.science, color: AppTheme.primaryColor, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(lab.testName,
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w600)),
                ),
                if (lab.isUrgent)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 2),
                    margin: const EdgeInsets.only(right: 6),
                    decoration: BoxDecoration(
                      color: AppTheme.errorColor,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(lab.priority.toUpperCase(),
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold)),
                  ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    lab.status.replaceAll('_', ' ').toUpperCase(),
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: statusColor),
                  ),
                ),
              ],
            ),
            if (lab.testType != null) ...[
              const SizedBox(height: 4),
              Text(lab.testType!,
                  style: TextStyle(fontSize: 13, color: AppTheme.gray600)),
            ],
            if (lab.results != null && lab.results!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text('Results: ${lab.results!}',
                  style: const TextStyle(fontSize: 13)),
            ],
            if (lab.abnormalFlags.isNotEmpty) ...[
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                children: lab.abnormalFlags.map((f) => Chip(
                  label: Text(f, style: const TextStyle(fontSize: 11)),
                  backgroundColor: AppTheme.errorColor.withValues(alpha: 0.1),
                  side: BorderSide(
                      color: AppTheme.errorColor.withValues(alpha: 0.3)),
                  padding: EdgeInsets.zero,
                )).toList(),
              ),
            ],
            if (lab.requiresFollowup) ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  Icon(Icons.flag, size: 14, color: AppTheme.warningColor),
                  const SizedBox(width: 4),
                  Text('Follow-up required',
                      style: TextStyle(
                          fontSize: 12, color: AppTheme.warningColor)),
                ],
              ),
            ],
          ],
        ),
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
      return _EmptyState(
        icon: Icons.folder_outlined,
        message: 'No documents',
      );
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

class _DocumentCard extends StatelessWidget {
  final MedicalDocumentModel doc;
  const _DocumentCard({required this.doc});

  @override
  Widget build(BuildContext context) {
    IconData icon;
    if (doc.isPdf) {
      icon = Icons.picture_as_pdf;
    } else if (doc.isImage) {
      icon = Icons.image;
    } else {
      icon = Icons.insert_drive_file;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppTheme.primaryColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: AppTheme.primaryColor),
        ),
        title: Text(doc.title,
            style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(
          [
            doc.documentType.replaceAll('_', ' '),
            if (doc.fileSizeDisplay.isNotEmpty) doc.fileSizeDisplay,
            if (doc.isConfidential) 'Confidential',
          ].join(' · '),
          style: TextStyle(fontSize: 12, color: AppTheme.gray600),
        ),
        trailing: doc.isConfidential
            ? Icon(Icons.lock, size: 16, color: AppTheme.warningColor)
            : null,
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

  const _SectionHeader(this.title,
      {this.badge, this.badgeColor, this.icon});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, size: 18, color: AppTheme.gray600),
            const SizedBox(width: 6),
          ],
          Text(title,
              style: const TextStyle(
                  fontSize: 16, fontWeight: FontWeight.bold)),
          if (badge != null) ...[
            const SizedBox(width: 8),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: badgeColor ?? AppTheme.errorColor,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(badge!,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold)),
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
            child: Text(label,
                style: TextStyle(
                    color: AppTheme.gray600,
                    fontWeight: FontWeight.w500,
                    fontSize: 13)),
          ),
          Expanded(
            child: Text(value,
                style: const TextStyle(
                    fontWeight: FontWeight.w600, fontSize: 13)),
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
          Icon(icon, size: 64, color: AppTheme.gray600.withValues(alpha: 0.5)),
          const SizedBox(height: 12),
          Text(message,
              style: TextStyle(fontSize: 16, color: AppTheme.gray600)),
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
          Icon(Icons.error_outline, size: 48, color: AppTheme.errorColor),
          const SizedBox(height: 12),
          Text(message,
              textAlign: TextAlign.center,
              style: TextStyle(color: AppTheme.gray600)),
          const SizedBox(height: 16),
          ElevatedButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}
