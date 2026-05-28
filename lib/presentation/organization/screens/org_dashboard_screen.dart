import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../config/theme.dart';
import '../../../core/platform.dart';
import '../../../data/models/organization_models_enhanced.dart';
import '../../../data/providers/auth_provider.dart';
import '../../../core/api/api_client.dart';
import '../../../data/repositories/organization_repository.dart';
import '../../common/error_view.dart';
import '../../subscription/screens/subscription_details_screen.dart';
import '../../reporting/screens/reporting_screen.dart';

class OrgDashboardScreen extends StatefulWidget {
  const OrgDashboardScreen({super.key});

  @override
  State<OrgDashboardScreen> createState() => _OrgDashboardScreenState();
}

class _OrgDashboardScreenState extends State<OrgDashboardScreen> {
  OrganizationEnhancedModel? _org;
  OrgStatsModel? _stats;
  bool _loading = true;
  String? _loadError;
  bool _statsError = false;

  late final OrganizationRepository _repository;

  @override
  void initState() {
    super.initState();
    _repository = OrganizationRepository(
      apiClient: context.read<ApiClient>(),
    );
    _load();
  }

  Future<void> _load() async {
    final orgId = context.read<AuthProvider>().organizationId;
    if (orgId == null) {
      setState(() {
        _loading = false;
        _loadError = 'No organisation found for this account.';
      });
      return;
    }

    setState(() {
      _loading = true;
      _loadError = null;
      _statsError = false;
    });

    final results = await Future.wait([
      _repository
          .getOrganization(orgId)
          .then<({OrganizationEnhancedModel? org, String? err})>(
              (v) => (org: v, err: null))
          .catchError((e) =>
              (org: null, err: e.toString())
                  as ({OrganizationEnhancedModel? org, String? err})),
      _repository
          .getOrgStats(orgId)
          .then<({OrgStatsModel? stats, String? err})>(
              (v) => (stats: v, err: null))
          .catchError((e) =>
              (stats: null, err: e.toString())
                  as ({OrgStatsModel? stats, String? err})),
    ]);

    if (!mounted) return;

    final orgResult =
        results[0] as ({OrganizationEnhancedModel? org, String? err});
    final statsResult =
        results[1] as ({OrgStatsModel? stats, String? err});

    if (orgResult.org == null) {
      setState(() {
        _loading = false;
        _loadError = orgResult.err;
      });
      return;
    }

    setState(() {
      _org = orgResult.org;
      _stats = statsResult.stats;
      _statsError = statsResult.stats == null;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (kIsIOS) {
      return CupertinoPageScaffold(
        navigationBar: const CupertinoNavigationBar(
          middle: Text('Overview'),
        ),
        child: SafeArea(child: _buildContent()),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Overview')),
      body: _buildContent(),
    );
  }

  Widget _buildContent() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_loadError != null) {
      return ErrorView(message: _loadError!, onRetry: _load);
    }
    return _buildBody();
  }

  Widget _buildBody() {
    final isWide = MediaQuery.of(context).size.width > 700;
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        children: [
          _GradientHeader(org: _org!, stats: _stats, statsError: _statsError),
          _SubscriptionBanner(org: _org!),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Text(
              'QUICK ACTIONS',
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                  color: Colors.grey.shade600),
            ),
          ),
          _QuickActions(isWide: isWide),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

// ── Gradient header ──────────────────────────────────────────────────────────

class _GradientHeader extends StatelessWidget {
  final OrganizationEnhancedModel org;
  final OrgStatsModel? stats;
  final bool statsError;

  const _GradientHeader(
      {required this.org, this.stats, required this.statsError});

  static const _typeLabels = {
    'state': 'State',
    'federal': 'Federal',
    'private_group': 'Private Group',
    'ngo': 'NGO',
    'standalone': 'Standalone',
  };

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width > 700;

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
          Text(
            org.name,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            _typeLabels[org.type] ?? org.type,
            style: const TextStyle(color: Colors.white70, fontSize: 13),
          ),
          const SizedBox(height: 16),
          isWide
              ? Row(children: _buildStatTiles())
              : Row(children: _buildStatTiles()),
        ],
      ),
    );
  }

  List<Widget> _buildStatTiles() {
    final tiles = [
      _DashStatTile(
          label: 'Facilities',
          value: statsError ? '—' : '${stats?.totalFacilities ?? '—'}',
          warning: statsError),
      const SizedBox(width: 8),
      _DashStatTile(
          label: 'Staff',
          value: statsError ? '—' : '${stats?.totalStaff ?? '—'}',
          warning: statsError),
      const SizedBox(width: 8),
      _DashStatTile(
          label: 'Patients',
          value: statsError ? '—' : '${stats?.totalPatients ?? '—'}',
          warning: statsError),
    ];
    return tiles;
  }
}

class _DashStatTile extends StatelessWidget {
  final String label;
  final String value;
  final bool warning;

  const _DashStatTile(
      {required this.label, required this.value, this.warning = false});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(children: [
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Text(value,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold)),
            if (warning) ...[
              const SizedBox(width: 4),
              const Icon(Icons.warning_amber,
                  size: 14, color: Colors.white70),
            ],
          ]),
          const SizedBox(height: 2),
          Text(label,
              style:
                  const TextStyle(color: Colors.white70, fontSize: 11)),
        ]),
      ),
    );
  }
}

// ── Subscription banner ──────────────────────────────────────────────────────

class _SubscriptionBanner extends StatelessWidget {
  final OrganizationEnhancedModel org;

  const _SubscriptionBanner({required this.org});

  @override
  Widget build(BuildContext context) {
    final Color bg;
    final Color textColor;
    final String message;
    final IconData icon;

    switch (org.subscriptionStatus) {
      case 'trial':
        final days = org.trialDaysRemaining ?? 0;
        bg = const Color(0xFFFFFBEB);
        textColor = const Color(0xFF92400E);
        icon = Icons.access_time;
        message = days > 0
            ? '$days day${days == 1 ? '' : 's'} left in free trial'
            : 'Trial expired';
      case 'active':
        bg = const Color(0xFFF0FDF4);
        textColor = const Color(0xFF166534);
        icon = Icons.check_circle_outline;
        message = 'Subscription active';
      case 'suspended':
      case 'cancelled':
        bg = const Color(0xFFFEF2F2);
        textColor = const Color(0xFF991B1B);
        icon = Icons.warning_outlined;
        message = org.subscriptionStatus == 'suspended'
            ? 'Subscription suspended'
            : 'Subscription cancelled';
      default:
        return const SizedBox.shrink();
    }

    return InkWell(
      onTap: () => Navigator.of(context).push(
        kIsIOS
            ? CupertinoPageRoute<void>(
                builder: (_) => const SubscriptionDetailsScreen())
            : MaterialPageRoute<void>(
                builder: (_) => const SubscriptionDetailsScreen()),
      ),
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: textColor.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            Icon(icon, size: 16, color: textColor),
            const SizedBox(width: 8),
            Expanded(
              child: Text(message,
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: textColor)),
            ),
            Icon(Icons.chevron_right, size: 16, color: textColor),
          ],
        ),
      ),
    );
  }
}

// ── Quick actions ────────────────────────────────────────────────────────────

class _QuickActions extends StatelessWidget {
  final bool isWide;

  const _QuickActions({required this.isWide});

  @override
  Widget build(BuildContext context) {
    final actions = [
      _ActionTile(
        icon: Icons.account_balance_wallet_outlined,
        label: 'Subscription & Billing',
        onTap: () => _push(context, const SubscriptionDetailsScreen()),
      ),
      _ActionTile(
        icon: Icons.bar_chart_outlined,
        label: 'Reporting & Compliance',
        onTap: () => _push(context, const ReportingScreen()),
      ),
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: GridView.count(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisCount: isWide ? 4 : 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.4,
        children: actions,
      ),
    );
  }

  void _push(BuildContext context, Widget screen) {
    Navigator.of(context).push(
      kIsIOS
          ? CupertinoPageRoute<void>(builder: (_) => screen)
          : MaterialPageRoute<void>(builder: (_) => screen),
    );
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ActionTile(
      {required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 28, color: AppTheme.primaryColor),
              const SizedBox(height: 8),
              Text(
                label,
                style: const TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w500),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
