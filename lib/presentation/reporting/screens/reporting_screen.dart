import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../config/theme.dart';
import '../../../data/providers/auth_provider.dart';
import '../../../data/providers/reporting_provider.dart';
import '../../../data/repositories/reporting_repository.dart';

class ReportingScreen extends StatefulWidget {
  const ReportingScreen({super.key});

  @override
  State<ReportingScreen> createState() => _ReportingScreenState();
}

class _ReportingScreenState extends State<ReportingScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadAll());
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _loadAll() async {
    final auth = context.read<AuthProvider>();
    final rp = context.read<ReportingProvider>();
    final orgId = auth.organizationId;
    final tenantId = auth.activeFacility?.id;

    await Future.wait([
      if (orgId != null) rp.loadOrgDashboard(orgId),
      if (tenantId != null) rp.loadTenantDashboard(tenantId),
      if (tenantId != null) rp.loadAuditLog(tenantId, refresh: true),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reports & Compliance'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh),
            onPressed: _loadAll,
          ),
        ],
        bottom: TabBar(
          controller: _tabs,
          tabs: const [
            Tab(text: 'Organisation'),
            Tab(text: 'Facility'),
            Tab(text: 'Audit Log'),
          ],
        ),
      ),
      body: Consumer<ReportingProvider>(
        builder: (context, rp, _) {
          if (rp.error != null) {
            return _ErrorView(
                message: rp.error!, onRetry: _loadAll);
          }

          return TabBarView(
            controller: _tabs,
            children: [
              _OrgDashboardTab(rp: rp),
              _TenantDashboardTab(rp: rp),
              _AuditLogTab(rp: rp),
            ],
          );
        },
      ),
    );
  }
}

// ── Organisation Dashboard Tab ────────────────────────────────────────────────

class _OrgDashboardTab extends StatelessWidget {
  final ReportingProvider rp;
  const _OrgDashboardTab({required this.rp});

  @override
  Widget build(BuildContext context) {
    if (rp.loadingOrg && rp.orgStats == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final stats = rp.orgStats;

    if (stats == null) {
      return const _EmptyStats(
        icon: Icons.bar_chart_outlined,
        message: 'Organisation stats not yet computed',
        subtitle: 'Stats are generated nightly. '
            'Check back after the first nightly run.',
      );
    }

    return RefreshIndicator(
      onRefresh: () async {
        final auth = context.read<AuthProvider>();
        final orgId = auth.organizationId;
        if (orgId != null) {
          await context.read<ReportingProvider>().loadOrgDashboard(orgId);
        }
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SectionHeader('Overview'),
            _StatsGrid([
              _StatItem('Facilities',
                  _str(stats['total_tenants']), Icons.business),
              _StatItem('Staff Members',
                  _str(stats['total_staff']), Icons.people),
              _StatItem('Total Patients',
                  _str(stats['total_patients']), Icons.personal_injury),
              _StatItem('Active Subscriptions',
                  _str(stats['active_subscriptions']), Icons.subscriptions),
            ]),
            const SizedBox(height: 24),
            if (stats['by_facility'] != null) ...[
              _SectionHeader('Per-Facility Breakdown'),
              ..._buildFacilityRows(stats['by_facility']),
            ],
            if (stats['generated_at'] != null) ...[
              const SizedBox(height: 16),
              Text(
                'Stats generated: ${_formatTs(stats['generated_at'])}',
                style: const TextStyle(
                    fontSize: 11, color: AppTheme.gray600),
              ),
            ],
          ],
        ),
      ),
    );
  }

  List<Widget> _buildFacilityRows(dynamic raw) {
    if (raw is! List) return [];
    return raw.map((item) {
      final m = item as Map;
      return Card(
        margin: const EdgeInsets.only(bottom: 8),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                m['name'] as String? ?? 'Facility',
                style: const TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 14),
              ),
              const SizedBox(height: 8),
              Row(children: [
                _MiniStat('Patients', _str(m['patients'])),
                const SizedBox(width: 16),
                _MiniStat('Staff', _str(m['staff'])),
                const SizedBox(width: 16),
                _MiniStat('Appointments', _str(m['appointments'])),
              ]),
            ],
          ),
        ),
      );
    }).toList();
  }
}

// ── Facility Dashboard Tab ────────────────────────────────────────────────────

class _TenantDashboardTab extends StatelessWidget {
  final ReportingProvider rp;
  const _TenantDashboardTab({required this.rp});

  @override
  Widget build(BuildContext context) {
    if (rp.loadingTenant && rp.tenantStats == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final stats = rp.tenantStats;

    if (stats == null) {
      return const _EmptyStats(
        icon: Icons.analytics_outlined,
        message: 'Facility stats not yet computed',
        subtitle: 'Stats are generated nightly. '
            'Check back after the first nightly run.',
      );
    }

    return RefreshIndicator(
      onRefresh: () async {
        final auth = context.read<AuthProvider>();
        final tenantId = auth.activeFacility?.id;
        if (tenantId != null) {
          await context
              .read<ReportingProvider>()
              .loadTenantDashboard(tenantId);
        }
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SectionHeader('Patient Activity'),
            _StatsGrid([
              _StatItem('Total Patients',
                  _str(stats['total_patients']), Icons.personal_injury),
              _StatItem('New (30 days)',
                  _str(stats['new_patients_30d']), Icons.person_add),
              _StatItem('Appointments',
                  _str(stats['total_appointments']), Icons.event),
              _StatItem('Prescriptions',
                  _str(stats['total_prescriptions']), Icons.medication),
            ]),
            const SizedBox(height: 24),
            _SectionHeader('Clinical Activity'),
            _StatsGrid([
              _StatItem('Lab Orders',
                  _str(stats['total_lab_results']), Icons.science),
              _StatItem('Documents',
                  _str(stats['total_documents']), Icons.folder),
              _StatItem('Emergency Events',
                  _str(stats['emergency_access_count']),
                  Icons.warning_amber,
                  color: AppTheme.errorColor),
              _StatItem('Access Grants',
                  _str(stats['access_grants_count']), Icons.shield),
            ]),
            const SizedBox(height: 24),
            _SectionHeader('Compliance'),
            _StatsGrid([
              _StatItem('Audit Events',
                  _str(stats['audit_log_count']), Icons.history),
              _StatItem('Unreviewed Emergency',
                  _str(stats['unreviewed_emergency_count']),
                  Icons.rate_review,
                  color: (stats['unreviewed_emergency_count'] as num? ?? 0) > 0
                      ? AppTheme.warningColor
                      : AppTheme.successColor),
            ]),
            if (stats['generated_at'] != null) ...[
              const SizedBox(height: 16),
              Text(
                'Stats generated: ${_formatTs(stats['generated_at'])}',
                style: const TextStyle(
                    fontSize: 11, color: AppTheme.gray600),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Audit Log Tab ─────────────────────────────────────────────────────────────

class _AuditLogTab extends StatefulWidget {
  final ReportingProvider rp;
  const _AuditLogTab({required this.rp});

  @override
  State<_AuditLogTab> createState() => _AuditLogTabState();
}

class _AuditLogTabState extends State<_AuditLogTab> {
  final _scrollCtrl = ScrollController();

  // Filter state
  String? _actionFilter;
  String? _authorityFilter;
  bool? _emergencyFilter;

  static const _actions = [
    null,
    'viewed',
    'created',
    'updated',
    'deleted',
    'emergency_access',
    'access_denied',
  ];

  static const _authorities = [
    null,
    'primary_provider',
    'intra_tenant_grant',
    'cross_tenant_grant',
    'emergency',
    'denied',
  ];

  @override
  void initState() {
    super.initState();
    _scrollCtrl.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollCtrl.position.pixels >=
        _scrollCtrl.position.maxScrollExtent - 300) {
      final auth = context.read<AuthProvider>();
      final tenantId = auth.activeFacility?.id;
      if (tenantId != null) {
        widget.rp.loadMore(tenantId);
      }
    }
  }

  void _applyFilters() {
    final auth = context.read<AuthProvider>();
    final tenantId = auth.activeFacility?.id;
    if (tenantId == null) return;
    widget.rp.applyFilters(
      tenantId,
      action: _actionFilter,
      authority: _authorityFilter,
      emergency: _emergencyFilter,
    );
  }

  void _showFilters() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Filter Audit Log',
                  style: TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              DropdownButtonFormField<String?>(
                value: _actionFilter,
                decoration: const InputDecoration(labelText: 'Action'),
                items: _actions.map((a) => DropdownMenuItem(
                      value: a,
                      child: Text(a == null ? 'All actions' : _label(a)),
                    )).toList(),
                onChanged: (v) =>
                    setLocal(() => _actionFilter = v),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String?>(
                value: _authorityFilter,
                decoration:
                    const InputDecoration(labelText: 'Access authority'),
                items: _authorities.map((a) => DropdownMenuItem(
                      value: a,
                      child: Text(a == null
                          ? 'All authorities'
                          : _authorityLabel(a)),
                    )).toList(),
                onChanged: (v) =>
                    setLocal(() => _authorityFilter = v),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<bool?>(
                value: _emergencyFilter,
                decoration:
                    const InputDecoration(labelText: 'Emergency events'),
                items: const [
                  DropdownMenuItem(value: null, child: Text('All events')),
                  DropdownMenuItem(
                      value: true,
                      child: Text('Emergency only')),
                  DropdownMenuItem(
                      value: false,
                      child: Text('Non-emergency only')),
                ],
                onChanged: (v) =>
                    setLocal(() => _emergencyFilter = v),
              ),
              const SizedBox(height: 20),
              Row(children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      setLocal(() {
                        _actionFilter = null;
                        _authorityFilter = null;
                        _emergencyFilter = null;
                      });
                    },
                    child: const Text('Clear'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.of(ctx).pop();
                      _applyFilters();
                    },
                    child: const Text('Apply'),
                  ),
                ),
              ]),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final rp = widget.rp;
    final hasFilters = _actionFilter != null ||
        _authorityFilter != null ||
        _emergencyFilter != null;

    return Column(
      children: [
        // Filter bar
        Container(
          color: AppTheme.gray100,
          padding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Text(
                '${rp.auditTotal} events',
                style: const TextStyle(
                    fontSize: 13, color: AppTheme.gray600),
              ),
              const Spacer(),
              Badge(
                isLabelVisible: hasFilters,
                child: TextButton.icon(
                  icon: const Icon(Icons.filter_list, size: 18),
                  label: const Text('Filter'),
                  onPressed: _showFilters,
                ),
              ),
            ],
          ),
        ),

        if (rp.loadingAudit && rp.auditLogs.isEmpty)
          const Expanded(
              child: Center(child: CircularProgressIndicator()))
        else if (rp.auditLogs.isEmpty)
          const Expanded(
            child: _EmptyStats(
              icon: Icons.history_outlined,
              message: 'No audit events found',
              subtitle:
                  'Try changing the filter or check back later.',
            ),
          )
        else
          Expanded(
            child: RefreshIndicator(
              onRefresh: () {
                final auth = context.read<AuthProvider>();
                final tenantId = auth.activeFacility?.id ?? '';
                return widget.rp
                    .loadAuditLog(tenantId, refresh: true);
              },
              child: ListView.builder(
                controller: _scrollCtrl,
                padding: const EdgeInsets.all(8),
                itemCount: rp.auditLogs.length +
                    (rp.auditHasMore ? 1 : 0),
                itemBuilder: (ctx, i) {
                  if (i == rp.auditLogs.length) {
                    return const Padding(
                      padding: EdgeInsets.all(16),
                      child: Center(
                          child: CircularProgressIndicator()),
                    );
                  }
                  return _AuditEntryCard(entry: rp.auditLogs[i]);
                },
              ),
            ),
          ),
      ],
    );
  }

  String _label(String action) => switch (action) {
        'viewed'           => 'Viewed',
        'created'          => 'Created',
        'updated'          => 'Updated',
        'deleted'          => 'Deleted',
        'emergency_access' => 'Emergency Access',
        'access_denied'    => 'Access Denied',
        _                  => action,
      };

  String _authorityLabel(String a) => switch (a) {
        'primary_provider'   => 'Primary Provider',
        'intra_tenant_grant' => 'Intra-facility Grant',
        'cross_tenant_grant' => 'Cross-facility Grant',
        'emergency'          => 'Emergency',
        'denied'             => 'Denied',
        _                    => a,
      };
}

class _AuditEntryCard extends StatelessWidget {
  final AuditLogEntry entry;
  const _AuditEntryCard({required this.entry});

  @override
  Widget build(BuildContext context) {
    final emergencyColor = entry.wasEmergency
        ? AppTheme.errorColor
        : null;

    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: entry.wasEmergency
            ? BorderSide(
                color: AppTheme.errorColor.withValues(alpha: 0.4))
            : BorderSide.none,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Action icon
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: (emergencyColor ?? AppTheme.primaryColor)
                    .withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                _actionIcon(entry.action),
                size: 18,
                color: emergencyColor ?? AppTheme.primaryColor,
              ),
            ),
            const SizedBox(width: 12),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Text(
                      entry.actionDisplay,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                        color: emergencyColor,
                      ),
                    ),
                    if (entry.resourceType != null) ...[
                      const Text(' · ',
                          style: TextStyle(color: AppTheme.gray600)),
                      Text(
                        entry.resourceType!,
                        style: const TextStyle(
                            fontSize: 12, color: AppTheme.gray600),
                      ),
                    ],
                    const Spacer(),
                    if (entry.wasEmergency)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppTheme.errorColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'EMERGENCY',
                          style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.errorColor),
                        ),
                      ),
                  ]),
                  const SizedBox(height: 2),
                  Text(
                    entry.authorityDisplay,
                    style: const TextStyle(
                        fontSize: 11, color: AppTheme.gray600),
                  ),
                  if (entry.accessedAt != null)
                    Text(
                      _formatDate(entry.accessedAt!),
                      style: const TextStyle(
                          fontSize: 11, color: AppTheme.gray600),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _actionIcon(String action) => switch (action) {
        'viewed'           => Icons.visibility,
        'created'          => Icons.add_circle_outline,
        'updated'          => Icons.edit_outlined,
        'deleted'          => Icons.delete_outline,
        'emergency_access' => Icons.warning_amber,
        'access_denied'    => Icons.block,
        _                  => Icons.receipt_long_outlined,
      };
}

// ── Shared helpers ────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String text;
  const _SectionHeader(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        text,
        style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: AppTheme.gray900),
      ),
    );
  }
}

class _StatsGrid extends StatelessWidget {
  final List<_StatItem> items;
  const _StatsGrid(this.items);

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
      childAspectRatio: 1.6,
      children: items.map((s) => _StatCard(item: s)).toList(),
    );
  }
}

class _StatItem {
  final String label;
  final String value;
  final IconData icon;
  final Color? color;

  const _StatItem(this.label, this.value, this.icon, {this.color});
}

class _StatCard extends StatelessWidget {
  final _StatItem item;
  const _StatCard({required this.item});

  @override
  Widget build(BuildContext context) {
    final color = item.color ?? AppTheme.primaryColor;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(item.icon, color: color, size: 20),
          const SizedBox(height: 6),
          Text(
            item.value,
            style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: color),
          ),
          Text(
            item.label,
            style: const TextStyle(
                fontSize: 11, color: AppTheme.gray600),
            maxLines: 2,
          ),
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String label;
  final String value;
  const _MiniStat(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(value,
            style: const TextStyle(
                fontWeight: FontWeight.bold, fontSize: 15)),
        Text(label,
            style: const TextStyle(
                fontSize: 11, color: AppTheme.gray600)),
      ],
    );
  }
}

class _EmptyStats extends StatelessWidget {
  final IconData icon;
  final String message;
  final String subtitle;
  const _EmptyStats(
      {required this.icon,
      required this.message,
      required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                size: 56, color: AppTheme.gray600.withValues(alpha: 0.4)),
            const SizedBox(height: 16),
            Text(message,
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w600),
                textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text(subtitle,
                style: const TextStyle(
                    fontSize: 13, color: AppTheme.gray600),
                textAlign: TextAlign.center),
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
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline,
                size: 48, color: AppTheme.errorColor),
            const SizedBox(height: 12),
            Text(message,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppTheme.gray600)),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Retry'),
              onPressed: onRetry,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Formatting ────────────────────────────────────────────────────────────────

String _str(dynamic v) {
  if (v == null) return '—';
  if (v is num) return v.toInt().toString();
  return v.toString();
}

String _formatTs(dynamic v) {
  if (v == null) return '—';
  final dt = DateTime.tryParse(v.toString());
  if (dt == null) return v.toString();
  return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year} '
      '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
}

String _formatDate(DateTime dt) {
  final now = DateTime.now();
  final diff = now.difference(dt);
  if (diff.inDays == 0) {
    final h = diff.inHours;
    if (h == 0) return '${diff.inMinutes}m ago';
    return '${h}h ago';
  }
  if (diff.inDays < 7) return '${diff.inDays}d ago';
  return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
}
