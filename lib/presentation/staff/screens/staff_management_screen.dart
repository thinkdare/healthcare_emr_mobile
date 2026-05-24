import 'package:flutter/material.dart';
import '../../../config/theme.dart';
import '../../../data/models/auth_models.dart';
import '../../../data/repositories/staff_repository.dart';

class StaffManagementScreen extends StatefulWidget {
  final StaffRepository repository;
  const StaffManagementScreen({required this.repository, super.key});

  @override
  State<StaffManagementScreen> createState() => _StaffManagementScreenState();
}

class _StaffManagementScreenState extends State<StaffManagementScreen> {
  List<FacilityStaffMemberModel> _allStaff = [];
  List<ClinicalRankModel> _ranks = [];
  bool _loading = true;
  String? _error;
  String _searchQuery = '';
  String _typeFilter = 'all';
  String _statusFilter = 'active';
  bool _searchVisible = false;
  final _searchCtrl = TextEditingController();

  static const _staffTypeFilters = [
    ('all', 'All'),
    ('doctor', 'Doctor'),
    ('nurse', 'Nurse'),
    ('pharmacist', 'Pharmacist'),
    ('lab_tech', 'Lab Tech'),
    ('radiologist', 'Radiologist'),
    ('admin', 'Admin'),
    ('other', 'Other'),
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        widget.repository.getStaffMemberships(),
        widget.repository.getClinicalRanks(),
      ]);
      if (mounted) {
        setState(() {
          _allStaff = results[0] as List<FacilityStaffMemberModel>;
          _ranks = results[1] as List<ClinicalRankModel>;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  List<FacilityStaffMemberModel> get _filtered {
    return _allStaff.where((m) {
      if (_typeFilter != 'all' && m.staffType != _typeFilter) return false;
      if (_statusFilter == 'active' && !m.isActive) return false;
      if (_statusFilter == 'inactive' && m.isActive) return false;
      if (_searchQuery.length >= 2) {
        final q = _searchQuery.toLowerCase();
        if (!m.fullName.toLowerCase().contains(q) &&
            !m.email.toLowerCase().contains(q)) { return false; }
      }
      return true;
    }).toList();
  }

  void _openEditSheet(FacilityStaffMemberModel member) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => _EditSheet(
        member: member,
        ranks: _ranks,
        repository: widget.repository,
        onSaved: (updated) {
          setState(() {
            final idx = _allStaff
                .indexWhere((m) => m.membershipId == updated.membershipId);
            if (idx >= 0) _allStaff[idx] = updated;
          });
        },
        onRemoved: (membershipId) {
          setState(() =>
              _allStaff.removeWhere((m) => m.membershipId == membershipId));
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;
    return Scaffold(
      appBar: AppBar(
        title: _searchVisible
            ? TextField(
                controller: _searchCtrl,
                autofocus: true,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  hintText: 'Search staff…',
                  hintStyle: TextStyle(color: Colors.white60),
                  border: InputBorder.none,
                ),
                onChanged: (v) => setState(() => _searchQuery = v),
              )
            : const Text('Staff'),
        actions: [
          IconButton(
            icon: Icon(_searchVisible ? Icons.close : Icons.search),
            onPressed: () => setState(() {
              _searchVisible = !_searchVisible;
              if (!_searchVisible) {
                _searchQuery = '';
                _searchCtrl.clear();
              }
            }),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Text(_error!),
                  const SizedBox(height: 12),
                  ElevatedButton(
                      onPressed: _load, child: const Text('Retry')),
                ]))
              : Column(
                  children: [
                    // Type filter chips
                    SizedBox(
                      height: 44,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        children: _staffTypeFilters.map((f) {
                          final selected = _typeFilter == f.$1;
                          return Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: FilterChip(
                              label: Text(f.$2),
                              selected: selected,
                              onSelected: (_) =>
                                  setState(() => _typeFilter = f.$1),
                              selectedColor: AppTheme.primaryColor
                                  .withValues(alpha: 0.2),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    // Status filter
                    Padding(
                      padding:
                          const EdgeInsets.fromLTRB(12, 0, 12, 8),
                      child: Row(children: [
                        for (final s in [
                          ('active', 'Active'),
                          ('inactive', 'Inactive'),
                          ('all', 'All')
                        ])
                          Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: ChoiceChip(
                              label: Text(s.$2),
                              selected: _statusFilter == s.$1,
                              onSelected: (_) =>
                                  setState(() => _statusFilter = s.$1),
                              selectedColor: s.$1 == 'active'
                                  ? Colors.green.withValues(alpha: 0.2)
                                  : s.$1 == 'inactive'
                                      ? Colors.red.withValues(alpha: 0.2)
                                      : AppTheme.primaryColor
                                          .withValues(alpha: 0.2),
                            ),
                          ),
                        const Spacer(),
                        Text('${filtered.length} members',
                            style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600)),
                      ]),
                    ),
                    Expanded(
                      child: RefreshIndicator(
                        onRefresh: _load,
                        child: filtered.isEmpty
                            ? const Center(child: Text('No staff found'))
                            : ListView.builder(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12),
                                itemCount: filtered.length,
                                itemBuilder: (_, i) => _StaffCard(
                                  member: filtered[i],
                                  onTap: () => _openEditSheet(filtered[i]),
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
    );
  }
}

// ── Staff card ───────────────────────────────────────────────────────────────

class _StaffCard extends StatelessWidget {
  final FacilityStaffMemberModel member;
  final VoidCallback onTap;
  const _StaffCard({required this.member, required this.onTap});

  Color get _avatarColor {
    const colors = {
      'doctor': Color(0xFF1565C0),
      'nurse': Color(0xFF00695C),
      'pharmacist': Color(0xFF6A1B9A),
      'lab_tech': Color(0xFFE65100),
      'admin': Color(0xFF37474F),
    };
    return colors[member.staffType] ?? const Color(0xFF546E7A);
  }

  @override
  Widget build(BuildContext context) {
    final rank = member.clinicalRank;
    return Opacity(
      opacity: member.isActive ? 1 : 0.6,
      child: Card(
        margin: const EdgeInsets.only(bottom: 8),
        child: ListTile(
          contentPadding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
          leading: CircleAvatar(
            backgroundColor: _avatarColor,
            child: Text(member.initials,
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold)),
          ),
          title: Text(member.fullName,
              style: const TextStyle(fontWeight: FontWeight.w600)),
          subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Text('${member.displayStaffType} · ',
                      style: const TextStyle(fontSize: 12)),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 5, vertical: 1),
                    decoration: BoxDecoration(
                      color: member.isActive
                          ? Colors.green.withValues(alpha: 0.1)
                          : Colors.red.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      member.isActive ? 'Active' : 'Inactive',
                      style: TextStyle(
                          fontSize: 10,
                          color: member.isActive
                              ? Colors.green.shade700
                              : Colors.red.shade700),
                    ),
                  ),
                ]),
                if (rank != null) ...[
                  const SizedBox(height: 4),
                  Wrap(spacing: 4, runSpacing: 2, children: [
                    if (rank.canPrescribe) _Chip('Rx', Colors.purple),
                    if (rank.canOrderLabs) _Chip('Labs', Colors.orange),
                    if (rank.canPerformEmergencyAccess)
                      _Chip('Emergency', Colors.red),
                  ]),
                ],
              ]),
          trailing: const Icon(Icons.chevron_right, color: Colors.grey),
          onTap: onTap,
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final Color color;
  const _Chip(this.label, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(label, style: TextStyle(fontSize: 10, color: color)),
    );
  }
}

// ── Edit bottom sheet ─────────────────────────────────────────────────────────

class _EditSheet extends StatefulWidget {
  final FacilityStaffMemberModel member;
  final List<ClinicalRankModel> ranks;
  final StaffRepository repository;
  final void Function(FacilityStaffMemberModel) onSaved;
  final void Function(String) onRemoved;

  const _EditSheet({
    required this.member,
    required this.ranks,
    required this.repository,
    required this.onSaved,
    required this.onRemoved,
  });

  @override
  State<_EditSheet> createState() => _EditSheetState();
}

class _EditSheetState extends State<_EditSheet> {
  late String _staffType;
  late String? _rankId;
  late bool _isActive;
  bool _saving = false;
  bool _removing = false;

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

  @override
  void initState() {
    super.initState();
    _staffType = widget.member.staffType;
    _rankId = widget.member.clinicalRank?.id;
    _isActive = widget.member.isActive;
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await widget.repository.updateMembership(
        widget.member.membershipId,
        staffType: _staffType,
        clinicalRankId: _rankId,
        isActive: _isActive,
      );
      if (mounted) {
        final rank = _rankId == null
            ? null
            : widget.ranks.firstWhere((r) => r.id == _rankId,
                orElse: () => widget.member.clinicalRank!);
        final updated = FacilityStaffMemberModel(
          membershipId: widget.member.membershipId,
          userId: widget.member.userId,
          firstName: widget.member.firstName,
          lastName: widget.member.lastName,
          email: widget.member.email,
          staffType: _staffType,
          isActive: _isActive,
          clinicalRank: rank,
        );
        widget.onSaved(updated);
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(e.toString()),
              backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _remove() async {
    final reasonCtrl = TextEditingController();
    String? reasonError;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: const Text('Remove from Facility'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            Text('Remove ${widget.member.fullName} from this facility?'),
            const SizedBox(height: 12),
            TextField(
              controller: reasonCtrl,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: 'Reason (required, min 10 chars)',
                errorText: reasonError,
              ),
            ),
          ]),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              style:
                  TextButton.styleFrom(foregroundColor: Colors.red),
              onPressed: () {
                final reason = reasonCtrl.text.trim();
                if (reason.length < 10) {
                  setS(() => reasonError =
                      'Reason must be at least 10 characters');
                  return;
                }
                Navigator.of(ctx).pop(true);
              },
              child: const Text('Remove'),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true) return;

    setState(() => _removing = true);
    try {
      await widget.repository.deleteMembership(
          widget.member.membershipId, reasonCtrl.text.trim());
      if (mounted) {
        widget.onRemoved(widget.member.membershipId);
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(e.toString()),
              backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _removing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      maxChildSize: 0.95,
      minChildSize: 0.4,
      expand: false,
      builder: (_, ctrl) => Padding(
        padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom),
        child: Column(children: [
          Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2))),
          Expanded(
            child: ListView(
                controller: ctrl,
                padding: const EdgeInsets.all(16),
                children: [
                  // Header
                  Row(children: [
                    CircleAvatar(
                      backgroundColor: AppTheme.primaryColor,
                      child: Text(widget.member.initials,
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(width: 12),
                    Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(widget.member.fullName,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 16)),
                          Text(widget.member.email,
                              style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade600)),
                        ]),
                  ]),
                  const Divider(height: 24),

                  // Staff type
                  DropdownButtonFormField<String>(
                    key: ValueKey(_staffType),
                    initialValue: _staffType,
                    decoration:
                        const InputDecoration(labelText: 'Staff Type'),
                    items: _staffTypes
                        .map((t) => DropdownMenuItem(
                            value: t.$1, child: Text(t.$2)))
                        .toList(),
                    onChanged: (v) => setState(() => _staffType = v!),
                  ),
                  const SizedBox(height: 16),

                  // Clinical rank
                  const Text('Clinical Rank',
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey)),
                  const SizedBox(height: 8),
                  ...widget.ranks.map((rank) => GestureDetector(
                        onTap: () =>
                            setState(() => _rankId = rank.id),
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 6),
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: _rankId == rank.id
                                ? AppTheme.primaryColor
                                    .withValues(alpha: 0.06)
                                : Colors.white,
                            border: Border.all(
                              color: _rankId == rank.id
                                  ? AppTheme.primaryColor
                                  : Colors.grey.shade300,
                              width: _rankId == rank.id ? 2 : 1,
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(children: [
                            Expanded(
                              child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(rank.name,
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w600)),
                                    Text('Level ${rank.hierarchyLevel}',
                                        style: TextStyle(
                                            fontSize: 11,
                                            color: Colors.grey.shade600)),
                                    const SizedBox(height: 4),
                                    Wrap(spacing: 4, children: [
                                      if (rank.canPrescribe)
                                        _RankChip('Rx', Colors.purple),
                                      if (rank.canOrderLabs)
                                        _RankChip('Labs', Colors.orange),
                                      if (rank.canPerformEmergencyAccess)
                                        _RankChip(
                                            'Emergency', Colors.red),
                                    ]),
                                  ]),
                            ),
                            if (_rankId == rank.id)
                              Icon(Icons.check_circle,
                                  color: AppTheme.primaryColor),
                          ]),
                        ),
                      )),
                  const SizedBox(height: 16),

                  // Active toggle
                  SwitchListTile(
                    value: _isActive,
                    onChanged: (v) => setState(() => _isActive = v),
                    title: const Text('Active'),
                    subtitle: const Text(
                        'Inactive staff can no longer log in'),
                    contentPadding: EdgeInsets.zero,
                  ),
                  const SizedBox(height: 16),

                  // Save
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _saving ? null : _save,
                      style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryColor,
                          padding: const EdgeInsets.symmetric(
                              vertical: 14)),
                      child: _saving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white))
                          : const Text('Save Changes',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Remove
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: _removing ? null : _remove,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                        side: const BorderSide(color: Colors.red),
                        padding:
                            const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: _removing
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.red))
                          : const Text('Remove from Facility'),
                    ),
                  ),
                ]),
          ),
        ]),
      ),
    );
  }
}

class _RankChip extends StatelessWidget {
  final String label;
  final Color color;
  const _RankChip(this.label, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(4)),
      child: Text(label, style: TextStyle(fontSize: 10, color: color)),
    );
  }
}
