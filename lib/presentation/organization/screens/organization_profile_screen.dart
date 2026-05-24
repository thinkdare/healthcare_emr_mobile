import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/platform.dart';
import '../../../config/theme.dart';
import '../../../data/models/organization_models_enhanced.dart';
import '../../../data/providers/auth_provider.dart';
import '../../../data/repositories/organization_repository.dart';

class OrganizationProfileScreen extends StatefulWidget {
  final OrganizationRepository repository;
  const OrganizationProfileScreen({required this.repository, super.key});

  @override
  State<OrganizationProfileScreen> createState() =>
      _OrganizationProfileScreenState();
}

class _OrganizationProfileScreenState
    extends State<OrganizationProfileScreen> {
  OrganizationEnhancedModel? _org;
  OrgStatsModel? _stats;
  bool _loading = true;
  bool _statsError = false;
  String? _loadError;
  bool _isEditing = false;
  bool _saving = false;

  late final TextEditingController _nameCtrl;
  late final TextEditingController _addressCtrl;
  late final TextEditingController _phoneCtrl;
  late final TextEditingController _emailCtrl;
  late final TextEditingController _taxIdCtrl;
  late final TextEditingController _billingEmailCtrl;
  late final TextEditingController _billingAddressCtrl;
  String? _selectedType;
  final _formKey = GlobalKey<FormState>();

  static const _orgTypes = [
    ('hospital', 'Hospital'),
    ('clinic', 'Clinic'),
    ('pharmacy', 'Pharmacy'),
    ('laboratory', 'Laboratory'),
    ('diagnostic_center', 'Diagnostic Center'),
    ('hospital_group', 'Hospital Group'),
    ('other', 'Other'),
  ];

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController();
    _addressCtrl = TextEditingController();
    _phoneCtrl = TextEditingController();
    _emailCtrl = TextEditingController();
    _taxIdCtrl = TextEditingController();
    _billingEmailCtrl = TextEditingController();
    _billingAddressCtrl = TextEditingController();
    _load();
  }

  @override
  void dispose() {
    for (final c in [
      _nameCtrl, _addressCtrl, _phoneCtrl, _emailCtrl,
      _taxIdCtrl, _billingEmailCtrl, _billingAddressCtrl,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    final orgId = context.read<AuthProvider>().organizationId;
    if (orgId == null) {
      setState(() {
        _loading = false;
        _loadError = 'No organisation found';
      });
      return;
    }

    setState(() {
      _loading = true;
      _loadError = null;
      _statsError = false;
    });

    final results = await Future.wait([
      widget.repository
          .getOrganization(orgId)
          .then<({OrganizationEnhancedModel? org, String? err})>(
              (v) => (org: v, err: null))
          .catchError((e) =>
              (org: null, err: e.toString())
                  as ({OrganizationEnhancedModel? org, String? err})),
      widget.repository
          .getOrgStats(orgId)
          .then<({OrgStatsModel? stats, String? err})>(
              (v) => (stats: v, err: null))
          .catchError((e) =>
              (stats: null, err: e.toString())
                  as ({OrgStatsModel? stats, String? err})),
    ]);

    if (!mounted) return;

    final orgResult = results[0] as ({OrganizationEnhancedModel? org, String? err});
    final statsResult = results[1] as ({OrgStatsModel? stats, String? err});

    if (orgResult.org == null) {
      setState(() {
        _loading = false;
        _loadError = orgResult.err;
      });
      return;
    }

    _populateControllers(orgResult.org!);
    setState(() {
      _org = orgResult.org;
      _stats = statsResult.stats;
      _statsError = statsResult.stats == null;
      _loading = false;
    });
  }

  void _populateControllers(OrganizationEnhancedModel org) {
    _nameCtrl.text = org.name;
    _addressCtrl.text = org.address;
    _phoneCtrl.text = org.phone ?? '';
    _emailCtrl.text = org.email ?? '';
    _taxIdCtrl.text = org.taxId ?? '';
    _billingEmailCtrl.text = org.billingEmail ?? '';
    _billingAddressCtrl.text = org.billingAddress ?? '';
    _selectedType = org.type;
  }

  void _cancelEdit() {
    _populateControllers(_org!);
    setState(() => _isEditing = false);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final updated = await widget.repository.updateOrganization(
        _org!.id,
        UpdateOrganizationRequest(
          name: _nameCtrl.text.trim(),
          type: _selectedType,
          address: _addressCtrl.text.trim(),
          phone: _phoneCtrl.text.trim().isEmpty
              ? null
              : _phoneCtrl.text.trim(),
          email: _emailCtrl.text.trim().isEmpty
              ? null
              : _emailCtrl.text.trim(),
          taxId: _taxIdCtrl.text.trim().isEmpty
              ? null
              : _taxIdCtrl.text.trim(),
          billingEmail: _billingEmailCtrl.text.trim().isEmpty
              ? null
              : _billingEmailCtrl.text.trim(),
          billingAddress: _billingAddressCtrl.text.trim().isEmpty
              ? null
              : _billingAddressCtrl.text.trim(),
        ),
      );
      if (mounted) {
        setState(() {
          _org = updated;
          _isEditing = false;
        });
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Organization'),
        actions: [
          if (_loading || _org == null)
            const SizedBox.shrink()
          else if (_isEditing) ...[
            TextButton(
              onPressed: _cancelEdit,
              child: const Text('Cancel',
                  style: TextStyle(color: Colors.white)),
            ),
            if (_saving)
              const Padding(
                padding: EdgeInsets.all(14),
                child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white)),
              )
            else
              TextButton(
                onPressed: _save,
                child: const Text('Save',
                    style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold)),
              ),
          ] else
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              onPressed: () => setState(() => _isEditing = true),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _loadError != null
              ? _ErrorView(message: _loadError!, onRetry: _load)
              : _buildBody(),
    );
  }

  Widget _buildBody() {
    final org = _org!;
    return Form(
      key: _formKey,
      child: ListView(
        children: [
          _StatsHeader(org: org, stats: _stats, statsError: _statsError),
          const SizedBox(height: 8),
          _SectionCard(
            title: 'Organization Details',
            editing: _isEditing,
            children: [
              _FieldRow(
                  label: 'Name',
                  controller: _nameCtrl,
                  editing: _isEditing,
                  required: true),
              if (_isEditing)
                _TypeDropdown(
                  value: _selectedType,
                  types: _orgTypes,
                  onChanged: (v) => setState(() => _selectedType = v),
                )
              else
                _ReadRow(
                    label: 'Type',
                    value: _orgTypes
                        .firstWhere((t) => t.$1 == org.type,
                            orElse: () => (org.type, org.type))
                        .$2),
              _FieldRow(
                  label: 'Address',
                  controller: _addressCtrl,
                  editing: _isEditing,
                  required: true),
              _FieldRow(
                  label: 'Phone',
                  controller: _phoneCtrl,
                  editing: _isEditing),
              _FieldRow(
                  label: 'Email',
                  controller: _emailCtrl,
                  editing: _isEditing),
              _FieldRow(
                  label: 'Tax ID',
                  controller: _taxIdCtrl,
                  editing: _isEditing),
            ],
          ),
          _SectionCard(
            title: 'Billing',
            editing: _isEditing,
            children: [
              _FieldRow(
                  label: 'Billing Email',
                  controller: _billingEmailCtrl,
                  editing: _isEditing),
              _FieldRow(
                  label: 'Billing Address',
                  controller: _billingAddressCtrl,
                  editing: _isEditing),
            ],
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

// ── Sub-widgets ──────────────────────────────────────────────────────────────

class _StatsHeader extends StatelessWidget {
  final OrganizationEnhancedModel org;
  final OrgStatsModel? stats;
  final bool statsError;
  const _StatsHeader(
      {required this.org, this.stats, required this.statsError});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [AppTheme.primaryColor, AppTheme.secondaryColor],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(org.name,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(org.type,
              style:
                  const TextStyle(color: Colors.white70, fontSize: 13)),
          const SizedBox(height: 16),
          Row(children: [
            _StatTile(
                label: 'Facilities',
                value: statsError
                    ? '—'
                    : '${stats?.totalFacilities ?? '—'}',
                warning: statsError),
            const SizedBox(width: 8),
            _StatTile(
                label: 'Staff',
                value: statsError
                    ? '—'
                    : '${stats?.totalStaff ?? '—'}',
                warning: statsError),
            const SizedBox(width: 8),
            _StatTile(
                label: 'Patients',
                value: statsError
                    ? '—'
                    : '${stats?.totalPatients ?? '—'}',
                warning: statsError),
          ]),
        ],
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  final String label;
  final String value;
  final bool warning;
  const _StatTile(
      {required this.label, required this.value, this.warning = false});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(children: [
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Text(value,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold)),
            if (warning) ...[
              const SizedBox(width: 4),
              const Icon(Icons.warning_amber,
                  size: 14, color: Colors.white70),
            ],
          ]),
          Text(label,
              style: const TextStyle(
                  color: Colors.white70, fontSize: 11)),
        ]),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final List<Widget> children;
  final bool editing;
  const _SectionCard(
      {required this.title,
      required this.children,
      required this.editing});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 6),
            decoration: BoxDecoration(
              color: editing
                  ? AppTheme.primaryColor.withValues(alpha: 0.08)
                  : Colors.grey.shade50,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: Text(
              title.toUpperCase(),
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.6,
                  color: editing
                      ? AppTheme.primaryColor
                      : Colors.grey.shade600),
            ),
          ),
          ...children,
        ],
      ),
    );
  }
}

class _FieldRow extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final bool editing;
  final bool required;
  const _FieldRow({
    required this.label,
    required this.controller,
    required this.editing,
    this.required = false,
  });

  @override
  Widget build(BuildContext context) {
    if (!editing) return _ReadRow(label: label, value: controller.text);
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 4),
      child: TextFormField(
        controller: controller,
        decoration: InputDecoration(
          labelText: required ? '$label *' : label,
          isDense: true,
        ),
        validator: required
            ? (v) => (v == null || v.trim().isEmpty)
                ? '$label is required'
                : null
            : null,
      ),
    );
  }
}

class _ReadRow extends StatelessWidget {
  final String label;
  final String value;
  const _ReadRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 4),
      child:
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label,
            style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
        const SizedBox(height: 2),
        Text(value.isEmpty ? '—' : value,
            style: const TextStyle(fontSize: 14)),
        const Divider(height: 14),
      ]),
    );
  }
}

class _TypeDropdown extends StatelessWidget {
  final String? value;
  final List<(String, String)> types;
  final ValueChanged<String?> onChanged;
  const _TypeDropdown(
      {this.value, required this.types, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 4),
      child: AdaptiveDropdown<String>(
        value: value,
        decoration: const InputDecoration(labelText: 'Type *', isDense: true),
        items: types
            .map((t) => DropdownMenuItem(value: t.$1, child: Text(t.$2)))
            .toList(),
        onChanged: onChanged,
        validator: (v) => v == null ? 'Type is required' : null,
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
        child: Column(mainAxisSize: MainAxisSize.min, children: [
      const Icon(Icons.error_outline, size: 48, color: Colors.red),
      const SizedBox(height: 12),
      Text(message, textAlign: TextAlign.center),
      const SizedBox(height: 16),
      ElevatedButton(onPressed: onRetry, child: const Text('Retry')),
    ]));
  }
}
