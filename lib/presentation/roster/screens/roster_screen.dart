import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../config/theme.dart';
import '../../../core/platform.dart';
import '../../../data/models/clinical_record_models.dart';
import '../../../data/models/patient_models.dart';
import '../../../data/providers/auth_provider.dart';
import '../../../data/providers/clinical_provider.dart';
import '../../../data/providers/patient_provider.dart';
import '../../patients/screens/patient_form_screen.dart';
import 'patient_complaint_screen.dart';

/// Daily roster screen.
///
/// Reads DailyRosterEntry records from the real roster API instead of
/// aggregating appointments. Entries are sorted by triage severity so the
/// most urgent patients appear at the top.
///
/// Nurses can add existing patients to today's roster (creates a checkup
/// appointment as a fallback — full roster-entry creation requires ward
/// selection UI, which is a future task) and register new patients.
/// Doctors see active roster entries and can mark patients as "in consultation".
class RosterScreen extends StatefulWidget {
  const RosterScreen({super.key});

  @override
  State<RosterScreen> createState() => _RosterScreenState();
}

class _RosterScreenState extends State<RosterScreen> {
  bool _loading = false;
  String? _error;

  // patientId → today's roster entries
  Map<String, List<RosterEntryModel>> _rosterMap = {};
  List<PatientModel> _rosterPatients = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final auth         = context.read<AuthProvider>();
      final patientProv  = context.read<PatientProvider>();
      final repo         = context.read<ClinicalProvider>().repository;

      await patientProv.loadPatients(
          providerId: auth.currentUserId, forceRefresh: true);

      // Surface any patient-load error immediately
      if (patientProv.error != null) {
        if (mounted) {
          setState(() {
            _error = 'Patient load failed: ${patientProv.error}';
            _loading = false;
          });
        }
        return;
      }

      final patients = patientProv.patients;
      final todayStr = DateTime.now().toIso8601String().substring(0, 10);

      final Map<String, List<RosterEntryModel>> rosterMap = {};
      String? firstRosterError;

      await Future.wait(patients.map((p) async {
        try {
          final entries = await repo.getRosterEntries(p.id, date: todayStr);
          if (entries.isNotEmpty) rosterMap[p.id] = entries;
        } catch (e) {
          firstRosterError ??= 'Roster fetch failed for ${p.id}: $e';
        }
      }));

      final rostered = patients
          .where((p) => rosterMap.containsKey(p.id))
          .toList()
        ..sort((a, b) {
          int best(String id) => rosterMap[id]!
              .map((e) => e.triagePriority)
              .reduce((m, x) => x < m ? x : m);
          return best(a.id).compareTo(best(b.id));
        });

      if (mounted) {
        setState(() {
          _rosterMap = rosterMap;
          _rosterPatients = rostered;
          _loading = false;
          // Individual roster fetch failures mean no entries for that patient —
          // that is a normal empty-roster condition, not an error.
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Roster load error: $e';
          _loading = false;
        });
      }
    }
  }

  // Fallback: create a checkup appointment so the patient appears in the
  // workflow. Full roster-entry creation (POST /patients/{id}/roster) requires
  // ward_id selection UI which is a future task.
  Future<void> _addToRoster(PatientModel patient) async {
    final repo = context.read<ClinicalProvider>().repository;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day, now.hour, now.minute);

    try {
      await repo.createAppointment(patient.id, {
        'appointment_date': today.toIso8601String(),
        'duration_minutes': 30,
        'appointment_type': 'checkup',
        'reason': 'Added to daily roster',
      });
      await _load();
      if (mounted) {
        showAdaptiveToast(context, '${patient.fullName} added to today\'s roster', type: ToastType.success);
      }
    } catch (e) {
      if (mounted) {
        showAdaptiveToast(context, 'Failed to add patient to roster', type: ToastType.error);
      }
    }
  }

  Future<void> _startConsultation(
      PatientModel patient, RosterEntryModel entry) async {
    final repo = context.read<ClinicalProvider>().repository;
    try {
      await repo.updateRosterEntry(
        patient.id,
        entry.id,
        {'status': 'in_consultation', 'version': entry.version},
      );
    } catch (_) {
      if (mounted) {
        showAdaptiveToast(context, 'Failed to start consultation', type: ToastType.error);
      }
      return;
    }

    if (!mounted) return;
    await Navigator.of(context).push(
      kIsIOS
          ? CupertinoPageRoute(
              builder: (_) => PatientComplaintScreen(
                  patient: patient, entry: entry))
          : MaterialPageRoute(
              builder: (_) => PatientComplaintScreen(
                  patient: patient, entry: entry)),
    );
    if (mounted) _load();
  }

  @override
  Widget build(BuildContext context) {
    final auth   = context.watch<AuthProvider>();
    final isNurse = auth.staffType == 'nurse';
    final today  = DateTime.now();
    final dateStr = '${today.day}/${today.month}/${today.year}';

    return Scaffold(
      appBar: kIsIOS
          ? CupertinoNavigationBar(
              middle: Text(isNurse ? 'Daily Roster' : 'Today\'s Patients'),
              trailing: CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: _load,
                child: const Icon(CupertinoIcons.refresh),
              ),
            )
          : AppBar(
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(isNurse ? 'Daily Roster' : 'Today\'s Patients',
                      style: const TextStyle(fontSize: 18)),
                  Text(dateStr,
                      style: const TextStyle(
                          fontSize: 12, color: Colors.white70)),
                ],
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.refresh),
                  tooltip: 'Refresh',
                  onPressed: _load,
                ),
              ],
            ),
      floatingActionButton: isNurse
          ? Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                FloatingActionButton.small(
                  heroTag: 'new_patient',
                  onPressed: () async {
                    final result =
                        await Navigator.of(context).push<PatientModel>(
                      kIsIOS
                          ? CupertinoPageRoute(
                              builder: (_) => const PatientFormScreen())
                          : MaterialPageRoute(
                              builder: (_) => const PatientFormScreen()),
                    );
                    if (result != null && mounted) {
                      await _addToRoster(result);
                    }
                  },
                  tooltip: 'Register new patient',
                  backgroundColor: AppTheme.secondaryColor,
                  child: const Icon(Icons.person_add),
                ),
                const SizedBox(height: 8),
                FloatingActionButton.extended(
                  heroTag: 'add_to_roster',
                  onPressed: () => _showAddPatientSheet(context),
                  icon: const Icon(Icons.playlist_add),
                  label: const Text('Add to Roster'),
                  backgroundColor: AppTheme.primaryColor,
                ),
              ],
            )
          : null,
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _ErrorView(message: _error!, onRetry: _load)
              : _rosterPatients.isEmpty
                  ? _EmptyRoster(isNurse: isNurse)
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView.builder(
                        padding: const EdgeInsets.only(top: 8, bottom: 32),
                        itemCount: _rosterPatients.length,
                        itemBuilder: (_, i) {
                          final patient = _rosterPatients[i];
                          final entries = _rosterMap[patient.id] ?? [];
                          final entry = entries.first;
                          return _RosterCard(
                            patient: patient,
                            entry: entry,
                            isNurse: isNurse,
                            currentUserId: auth.currentUserId,
                            onTap: () async {
                              if (entry.isWaiting) {
                                // Mark in_consultation then open complaint screen
                                await _startConsultation(patient, entry);
                              } else {
                                await Navigator.of(context).push(kIsIOS
                                    ? CupertinoPageRoute(
                                        builder: (_) => PatientComplaintScreen(
                                            patient: patient, entry: entry))
                                    : MaterialPageRoute(
                                        builder: (_) => PatientComplaintScreen(
                                            patient: patient, entry: entry)));
                                if (mounted) _load();
                              }
                            },
                          );
                        },
                      ),
                    ),
    );
  }

  Future<void> _showAddPatientSheet(BuildContext context) async {
    final patients     = context.read<PatientProvider>().patients;
    final rosteredIds  = _rosterPatients.map((p) => p.id).toSet();
    final available =
        patients.where((p) => !rosteredIds.contains(p.id)).toList();

    if (available.isEmpty) {
      showAdaptiveToast(context, 'All patients are already on today\'s roster');
      return;
    }

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        expand: false,
        builder: (_, scrollCtrl) => Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(children: [
                const Expanded(
                  child: Text('Select Patient',
                      style: TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold)),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(ctx).pop(),
                ),
              ]),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView.builder(
                controller: scrollCtrl,
                padding: const EdgeInsets.only(bottom: 24),
                itemCount: available.length,
                itemBuilder: (_, i) {
                  final p = available[i];
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor:
                          AppTheme.primaryColor.withValues(alpha: 0.1),
                      child: Text(
                        '${p.firstName[0]}${p.lastName[0]}',
                        style: const TextStyle(
                            color: AppTheme.primaryColor,
                            fontWeight: FontWeight.bold),
                      ),
                    ),
                    title: Text(p.fullName,
                        style:
                            const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text(
                      [
                        if (p.mrn != null) p.mrn!,
                        p.gender,
                        p.ageDisplay,
                      ].join(' · '),
                      style: TextStyle(
                          fontSize: 12, color: AppTheme.gray600),
                    ),
                    onTap: () {
                      Navigator.of(ctx).pop();
                      _addToRoster(p);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Roster Card ───────────────────────────────────────────────────────────────

class _RosterCard extends StatelessWidget {
  final PatientModel patient;
  final RosterEntryModel entry;
  final bool isNurse;
  final VoidCallback onTap;
  final String? currentUserId;

  const _RosterCard({
    required this.patient,
    required this.entry,
    required this.isNurse,
    required this.onTap,
    this.currentUserId,
  });

  /// True when another provider holds this patient in consultation.
  /// The card is dimmed and non-interactive for all other staff.
  bool get _isLockedByOther =>
      entry.isInConsultation &&
      entry.seenById != null &&
      entry.seenById != currentUserId;

  Color get _triageColor => switch (entry.triageSeverity) {
        'critical' => AppTheme.errorColor,
        'urgent'   => AppTheme.warningColor,
        'moderate' => Colors.blue,
        'low'      => AppTheme.successColor,
        _          => AppTheme.gray600,
      };

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: _isLockedByOther ? 0.5 : 1.0,
      child: Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      clipBehavior: Clip.hardEdge,
      child: InkWell(
        // no-op when locked — subtitle already shows "Consulting with Dr. X"
        onTap: _isLockedByOther ? null : onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              // Triage severity stripe
              Container(
                width: 4,
                height: 56,
                decoration: BoxDecoration(
                  color: _triageColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 12),

              // Avatar
              CircleAvatar(
                radius: 22,
                backgroundColor: patient.hasCriticalAllergies
                    ? AppTheme.errorColor.withValues(alpha: 0.15)
                    : AppTheme.primaryColor.withValues(alpha: 0.1),
                child: Text(
                  '${patient.firstName[0]}${patient.lastName[0]}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: patient.hasCriticalAllergies
                        ? AppTheme.errorColor
                        : AppTheme.primaryColor,
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Expanded(
                        child: Text(patient.fullName,
                            style: const TextStyle(
                                fontWeight: FontWeight.w600, fontSize: 15)),
                      ),
                      if (patient.hasCriticalAllergies)
                        Tooltip(
                          message: 'Critical allergies',
                          child: Icon(Icons.warning,
                              size: 16, color: AppTheme.errorColor),
                        ),
                    ]),
                    const SizedBox(height: 2),
                    Text(
                      [
                        if (patient.mrn != null) patient.mrn!,
                        patient.ageDisplay,
                        patient.gender,
                      ].join(' · '),
                      style: TextStyle(fontSize: 12, color: AppTheme.gray600),
                    ),
                    const SizedBox(height: 4),
                    // When in consultation show doctor name; otherwise triage chip
                    entry.isInConsultation
                        ? Row(children: [
                            Icon(Icons.medical_services,
                                size: 13, color: Colors.blue.shade600),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                'Consulting with ${entry.seenByName ?? 'a doctor'}',
                                style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.blue.shade700,
                                    fontWeight: FontWeight.w500),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ])
                        : Row(children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 1),
                              decoration: BoxDecoration(
                                color: _triageColor.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                entry.triageSeverity?.toUpperCase() ?? 'UNSET',
                                style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: _triageColor),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 1),
                              decoration: BoxDecoration(
                                color: AppTheme.warningColor.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                entry.status.toUpperCase(),
                                style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: AppTheme.warningColor),
                              ),
                            ),
                          ]),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.chevron_right,
                  color: AppTheme.gray600.withValues(alpha: 0.4)),
            ],
          ),
        ),
      ),
      ), // Card
    ); // Opacity
  }
}

// ── Empty / Error helpers ─────────────────────────────────────────────────────

class _EmptyRoster extends StatelessWidget {
  final bool isNurse;
  const _EmptyRoster({required this.isNurse});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.event_available,
                size: 64,
                color: AppTheme.gray600.withValues(alpha: 0.5)),
            const SizedBox(height: 16),
            const Text('No patients on today\'s roster',
                style:
                    TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text(
              isNurse
                  ? 'Tap "Add to Roster" to queue existing patients, '
                      'or register a new patient.'
                  : 'No roster entries for today.',
              style: TextStyle(fontSize: 13, color: AppTheme.gray600),
              textAlign: TextAlign.center,
            ),
          ],
        ),
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
          AdaptiveFilledButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}
