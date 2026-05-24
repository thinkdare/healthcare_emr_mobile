// ⚠️ MERGE GATE: This screen must not merge beyond local dev until
// StaffRegistrationController::invite() has a backend org-admin check deployed
// and a 403 test from a non-org-admin token passes in staging.
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/api/api_client.dart';
import '../../../core/platform.dart';
import '../../../config/theme.dart';
import '../../../data/models/auth_models.dart';
import '../../../data/providers/auth_provider.dart';
import '../../../data/repositories/staff_repository.dart';

class ProviderInvitationScreen extends StatefulWidget {
  const ProviderInvitationScreen({super.key});

  @override
  State<ProviderInvitationScreen> createState() =>
      _ProviderInvitationScreenState();
}

class _ProviderInvitationScreenState extends State<ProviderInvitationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();

  late final StaffRepository _repo;

  static const _staffTypes = [
    ('doctor', 'Doctor'),
    ('nurse', 'Nurse'),
    ('pharmacist', 'Pharmacist'),
    ('lab_tech', 'Lab Technician'),
    ('radiologist', 'Radiologist'),
    ('physiotherapist', 'Physiotherapist'),
    ('dentist', 'Dentist'),
    ('admin', 'Administrator'),
    ('other', 'Other'),
  ];

  String _selectedStaffType = 'doctor';
  String? _selectedRankId;
  List<ClinicalRankModel> _ranks = [];
  bool _ranksLoading = true;
  bool _submitting = false;
  String? _rankError;

  @override
  void initState() {
    super.initState();
    _repo = StaffRepository(apiClient: context.read<ApiClient>());
    _loadRanks();
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _loadRanks() async {
    try {
      final ranks = await _repo.getClinicalRanks();
      if (mounted) {
        setState(() {
          _ranks = ranks;
          _ranksLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _ranksLoading = false;
          _rankError = e.toString();
        });
      }
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedRankId == null) {
      showAdaptiveToast(context, 'Please select a clinical rank',
          type: ToastType.error);
      return;
    }
    setState(() => _submitting = true);
    try {
      await context.read<ApiClient>().post('/staff/invite', data: {
        'email': _emailController.text.trim(),
        'staff_type': _selectedStaffType,
        'clinical_rank_id': _selectedRankId,
      });
      if (mounted) {
        showAdaptiveToast(
          context,
          'Invitation sent to ${_emailController.text.trim()}',
          type: ToastType.success,
        );
        _emailController.clear();
        setState(() {
          _selectedStaffType = 'doctor';
          _selectedRankId = null;
        });
      }
    } catch (e) {
      if (mounted) {
        showAdaptiveToast(context, e.toString(), type: ToastType.error);
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final facilityName = context.read<AuthProvider>().facilityName;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Invite Staff'),
        actions: [
          if (_submitting)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white)),
            )
          else
            TextButton(
              onPressed: _submit,
              child:
                  const Text('Send', style: TextStyle(color: Colors.white)),
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Active facility banner
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withValues(alpha:0.08),
                borderRadius: BorderRadius.circular(8),
                border:
                    Border.all(color: AppTheme.primaryColor.withValues(alpha:0.3)),
              ),
              child: Row(children: [
                Icon(Icons.local_hospital_outlined,
                    size: 18, color: AppTheme.primaryColor),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Inviting to: $facilityName',
                    style: TextStyle(
                        color: AppTheme.primaryColor,
                        fontWeight: FontWeight.w600),
                  ),
                ),
              ]),
            ),
            const SizedBox(height: 20),

            // Email
            TextFormField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'Email address *',
                hintText: 'staff@clinic.com',
              ),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Email is required';
                if (!v.contains('@')) return 'Enter a valid email';
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Staff type
            AdaptiveDropdown<String>(
              value: _selectedStaffType,
              decoration: const InputDecoration(labelText: 'Staff type *'),
              items: _staffTypes
                  .map((t) => DropdownMenuItem(value: t.$1, child: Text(t.$2)))
                  .toList(),
              onChanged: (v) => setState(() => _selectedStaffType = v!),
            ),
            const SizedBox(height: 20),

            // Clinical rank selector
            Text('Clinical rank *',
                style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            if (_ranksLoading)
              const Center(child: CircularProgressIndicator())
            else if (_rankError != null)
              Text('Failed to load ranks: $_rankError',
                  style: const TextStyle(color: Colors.red))
            else
              ..._ranks.map((rank) => _RankCard(
                    rank: rank,
                    selected: _selectedRankId == rank.id,
                    onTap: () => setState(() => _selectedRankId = rank.id),
                  )),
          ],
        ),
      ),
    );
  }
}

class _RankCard extends StatelessWidget {
  final ClinicalRankModel rank;
  final bool selected;
  final VoidCallback onTap;

  const _RankCard(
      {required this.rank, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: selected ? AppTheme.primaryColor.withValues(alpha:0.06) : Colors.white,
          border: Border.all(
            color: selected ? AppTheme.primaryColor : Colors.grey.shade300,
            width: selected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Text(rank.name,
                        style:
                            const TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(width: 8),
                    Text('Level ${rank.hierarchyLevel}',
                        style: TextStyle(
                            fontSize: 11, color: Colors.grey.shade600)),
                  ]),
                  const SizedBox(height: 6),
                  Wrap(spacing: 4, runSpacing: 4, children: [
                    if (rank.canPrescribe)
                      _CapChip('Can Prescribe', Colors.purple),
                    if (rank.canOrderLabs)
                      _CapChip('Can Order Labs', Colors.orange),
                    if (rank.canPerformEmergencyAccess)
                      _CapChip('Emergency Access', Colors.red),
                  ]),
                ],
              ),
            ),
            if (selected)
              Icon(Icons.check_circle,
                  color: AppTheme.primaryColor, size: 20),
          ],
        ),
      ),
    );
  }
}

class _CapChip extends StatelessWidget {
  final String label;
  final Color color;
  const _CapChip(this.label, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha:0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(label, style: TextStyle(fontSize: 11, color: color)),
    );
  }
}
